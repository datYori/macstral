# /// script
# requires-python = ">=3.11"
# dependencies = ["starlette", "uvicorn", "httpx"]
# ///
"""
Debug capture proxy: sits between Vibe and Ollama, logs every /v1/chat/completions
request body, and flags the role-alternation violation that crashes the Devstral
template (mistral-vibe#255). Streams responses through untouched.

Run:   uv run scripts/capture-proxy.py            # listen :11435 -> forward :11434
Point Vibe at it:   just config ollama 11435
Reproduce the crash in Vibe (e.g. ESC-interrupt then send another message).
Restore when done:  just config ollama 11434

Captures land in .macstral/capture/ (gitignored):
  - requests.jsonl        one summary line per request
  - FAILED-<ts>.json      full request + upstream error body, for every upstream >=400
"""
import json
import os
import sys
import time

import httpx
import uvicorn
from starlette.applications import Starlette
from starlette.responses import Response, StreamingResponse
from starlette.routing import Route

LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "11435"))
OLLAMA_PORT = int(os.environ.get("OLLAMA_PORT", "11434"))
UPSTREAM = f"http://localhost:{OLLAMA_PORT}"

CAPTURE_DIR = os.path.join(os.path.dirname(__file__), "..", ".macstral", "capture")
os.makedirs(CAPTURE_DIR, exist_ok=True)
SUMMARY = os.path.join(CAPTURE_DIR, "requests.jsonl")

# Headers we must not relay verbatim (recomputed or hop-by-hop).
DROP_REQ = {"host", "content-length"}
DROP_RESP = {"content-length", "transfer-encoding", "connection", "content-type"}

client = httpx.AsyncClient(timeout=None)


def analyze_roles(messages):
    """Replicate the Devstral template's alternation counter (template L184-193).

    Counts only `user` and `assistant`-without-tool_calls; skips tool-call
    assistants and tool results. Counted roles must alternate user/assistant.
    Returns (compact role sequence, index of first violating message or None).
    """
    seq, idx, break_at = [], 0, None
    for i, m in enumerate(messages):
        role = m.get("role", "?")
        has_tc = bool(m.get("tool_calls"))
        counted = role == "user" or (role == "assistant" and not has_tc)
        tag = role + ("[tc]" if has_tc else "") + ("" if counted else "~skip")
        seq.append(tag)
        if counted:
            if (role == "user") != (idx % 2 == 0) and break_at is None:
                break_at = i
            idx += 1
    return seq, break_at


def log_request(method, path, status, body_bytes):
    parsed, msgs, tools = None, [], None
    if path.endswith("/chat/completions") and method == "POST":
        try:
            parsed = json.loads(body_bytes)
            msgs = parsed.get("messages", [])
            tools = bool(parsed.get("tools"))
        except (ValueError, AttributeError):
            parsed = None
    seq, break_at = analyze_roles(msgs) if parsed else ([], None)
    rec = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "method": method,
        "path": path,
        "status": status,
        "message_count": len(msgs),
        "has_tools": tools,
        "roles": seq,
        "alternation_break_index": break_at,
    }
    with open(SUMMARY, "a") as f:
        f.write(json.dumps(rec) + "\n")
    return rec, parsed


_fail_n = 0


def dump_failure(rec, request_json, status, resp_body):
    global _fail_n
    _fail_n += 1
    ts = time.strftime("%Y%m%d-%H%M%S")
    path = os.path.join(CAPTURE_DIR, f"FAILED-{ts}-{_fail_n:03d}.json")
    seq, break_at = analyze_roles((request_json or {}).get("messages", []))
    with open(path, "w") as f:
        json.dump(
            {
                "summary": rec,
                "role_sequence": seq,
                "alternation_break_index": break_at,
                "upstream_status": status,
                "upstream_body": _try_json(resp_body),
                "request": request_json,
            },
            f,
            indent=2,
        )
    bar = "!" * 60
    print(f"\n{bar}\nCAPTURED UPSTREAM {status} -> {path}", file=sys.stderr)
    print(f"  messages={rec['message_count']} tools={rec['has_tools']}", file=sys.stderr)
    print(f"  roles: {' -> '.join(seq)}", file=sys.stderr)
    if break_at is not None:
        print(f"  >>> alternation breaks at message index {break_at} <<<", file=sys.stderr)
    print(f"{bar}\n", file=sys.stderr)


def _try_json(b):
    try:
        return json.loads(b)
    except (ValueError, TypeError):
        return b.decode("utf-8", "replace") if isinstance(b, bytes) else b


async def proxy(request):
    body = await request.body()
    url = UPSTREAM + request.url.path
    if request.url.query:
        url += "?" + request.url.query
    headers = {k: v for k, v in request.headers.items() if k.lower() not in DROP_REQ}

    upstream = client.build_request(request.method, url, headers=headers, content=body)
    resp = await client.send(upstream, stream=True)

    out_headers = {k: v for k, v in resp.headers.items() if k.lower() not in DROP_RESP}
    ctype = resp.headers.get("content-type")

    if resp.status_code >= 400:
        # Errors are small and non-streamed: read fully so we can capture + relay.
        err_body = await resp.aread()
        await resp.aclose()
        rec, parsed = log_request(request.method, request.url.path, resp.status_code, body)
        dump_failure(rec, parsed, resp.status_code, err_body)
        return Response(err_body, status_code=resp.status_code, headers=out_headers, media_type=ctype)

    log_request(request.method, request.url.path, resp.status_code, body)

    async def relay():
        async for chunk in resp.aiter_raw():
            yield chunk
        await resp.aclose()

    return StreamingResponse(relay(), status_code=resp.status_code, headers=out_headers, media_type=ctype)


app = Starlette(routes=[Route("/{path:path}", proxy, methods=["GET", "POST", "PUT", "DELETE", "PATCH"])])

if __name__ == "__main__":
    print(f"capture-proxy: listening :{LISTEN_PORT} -> forwarding {UPSTREAM}", file=sys.stderr)
    print(f"captures -> {os.path.abspath(CAPTURE_DIR)}", file=sys.stderr)
    uvicorn.run(app, host="127.0.0.1", port=LISTEN_PORT, log_level="warning")
