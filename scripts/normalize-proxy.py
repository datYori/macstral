# /// script
# requires-python = ">=3.11"
# dependencies = ["starlette", "uvicorn", "httpx"]
# ///
"""Always-on normalizing proxy that sits between Vibe and Ollama.

    vibe  -->  normalize-proxy (LISTEN_PORT)  -->  Ollama (OLLAMA_PORT)

It repairs the message sequence so Devstral's strict chat template stops 500ing
on consecutive user messages (see scripts/normalize.py and mistral-vibe#255).
Only POST /v1/chat/completions request bodies are inspected; every response --
including streamed token output -- is forwarded through verbatim.

Run standalone:
    LISTEN_PORT=11436 OLLAMA_PORT=11434 uv run scripts/normalize-proxy.py

'just up' starts this for you and points ~/.vibe/config.toml at LISTEN_PORT.
"""
import json
import os
import sys

import httpx
import uvicorn
from starlette.applications import Starlette
from starlette.responses import StreamingResponse
from starlette.routing import Route

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from normalize import normalize  # noqa: E402  (after sys.path tweak)

LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "11436"))
OLLAMA_PORT = int(os.environ.get("OLLAMA_PORT", "11434"))
UPSTREAM = f"http://localhost:{OLLAMA_PORT}"

# Hop-by-hop / recomputed headers we must not relay verbatim.
DROP_REQ = {"host", "content-length"}
DROP_RESP = {"content-length", "transfer-encoding", "connection", "content-type"}

client = httpx.AsyncClient(timeout=None)


def fix_body(path, method, body):
    """Normalize chat-completion message lists; pass anything else through."""
    if method != "POST" or not path.endswith("/chat/completions"):
        return body
    try:
        payload = json.loads(body)
    except ValueError:
        return body
    messages = payload.get("messages")
    if not isinstance(messages, list):
        return body
    fixed, inserted = normalize(messages)
    if not inserted:
        return body
    payload["messages"] = fixed
    print(
        f"normalize: inserted {inserted} filler turn(s) "
        f"({len(messages)} -> {len(fixed)} msgs) to keep Devstral alternation",
        file=sys.stderr,
    )
    return json.dumps(payload).encode()


async def proxy(request):
    body = fix_body(request.url.path, request.method, await request.body())
    url = UPSTREAM + request.url.path
    if request.url.query:
        url += "?" + request.url.query
    headers = {k: v for k, v in request.headers.items() if k.lower() not in DROP_REQ}

    upstream = client.build_request(request.method, url, headers=headers, content=body)
    resp = await client.send(upstream, stream=True)
    out_headers = {k: v for k, v in resp.headers.items() if k.lower() not in DROP_RESP}

    async def relay():
        async for chunk in resp.aiter_raw():
            yield chunk
        await resp.aclose()

    return StreamingResponse(
        relay(),
        status_code=resp.status_code,
        headers=out_headers,
        media_type=resp.headers.get("content-type"),
    )


app = Starlette(
    routes=[Route("/{path:path}", proxy, methods=["GET", "POST", "PUT", "DELETE", "PATCH"])]
)

if __name__ == "__main__":
    print(f"normalize-proxy: listening :{LISTEN_PORT} -> forwarding {UPSTREAM}", file=sys.stderr)
    uvicorn.run(app, host="127.0.0.1", port=LISTEN_PORT, log_level="warning")
