# Role-alternation fix (the `roles must alternate` 500)

## Symptom

Vibe sessions intermittently fail with a 500 from the local model:

```
LLM backend error [local-ollama]
  status: 500 Internal Server Error
  ... Jinja Exception: After the optional system message, conversation roles
  must alternate user and assistant roles except for tool calls and results.
```

It looks like an out-of-memory crash but is not: the model stays resident
(`ollama ps` shows it loaded, no eviction) and the Ollama logs show no
allocation failure. The error is raised while *rendering the chat template*,
before any token generation.

## Cause

Devstral's GGUF ships a strict Jinja chat template. A guard near the top counts
only "real" turns -- `user` messages and `assistant` messages **without**
`tool_calls` -- and requires them to strictly alternate user/assistant. Tool-call
assistant messages and `tool` results are skipped by that counter.

Mistral Vibe stopped normalizing this. Its v2.10.0 changelog reads *"Drop
consecutive user-message merging in LLM backends"*, and its `generic` backend
forwards the message list to Ollama unchanged. So Vibe can send two counted
`user` messages in a row, which the template rejects. The most common way to hit
it (matching upstream [mistral-vibe#255](https://github.com/mistralai/mistral-vibe/issues/255)):

```
user  ->  assistant[tool_calls]  ->  tool result  ->  user
```

You interrupt (ESC) mid tool-loop and type again; the assistant never emitted a
final text turn, so the counter sees `user ... user` and raises. Mistral's hosted
API normalizes this server-side, which is why only local Ollama / llama.cpp users
see it.

## Current fix: normalize-proxy (shipped)

macstral inserts a tiny proxy between Vibe and Ollama:

```
vibe  ->  normalize-proxy :11436  ->  ollama :11434
```

`scripts/normalize.py` walks the message list, tracks the template's counted
parity, and inserts one minimal filler turn of the expected role wherever two
counted same-role messages would collide. Clean conversations pass through
unchanged. `scripts/normalize-proxy.py` applies this to
`POST /v1/chat/completions` bodies and forwards everything else (including
streamed responses) verbatim.

`just up` starts the proxy (pid in `.macstral/proxy.pid`, log in
`.macstral/proxy.log`) and points `~/.vibe/config.toml` at port 11436. `just down`
stops it. The proxy needs [`uv`](https://docs.astral.sh/uv/), which fetches its
deps (starlette/uvicorn/httpx) on first run.

Why a proxy and not a template edit: it leaves Devstral's validated tool-format
template untouched (no risk of silently breaking tool-call rendering), survives
model re-pulls, and mirrors what Vibe used to do and what the Mistral API does.

### Debug companion

`scripts/capture-proxy.py` is the same idea minus the repair: it logs every
request body and flags the exact alternation break, writing
`.macstral/capture/requests.jsonl` and `FAILED-*.json`. Use it to inspect a real
failing sequence: start it, `just config ollama 11435`, `just vibe`, reproduce,
then `just config ollama 11434` to restore.

## Roadmap alternative: Go-template override (not implemented)

Instead of a runtime proxy, patch the template so the model itself tolerates the
sequence. Ollama's `TEMPLATE` directive in a Modelfile reuses the existing weight
blob (only a ~5 KB diff layer is stored -- no ~11.5 GB GGUF rewrite), so this is
cheap to build. The catch: `TEMPLATE` is **Go**-template syntax, not Jinja
(confirmed: feeding the GGUF's Jinja to `ollama create` fails with
`function "raise_exception" not defined`).

Plan when we pick this up:

1. Port Devstral's tool format to an Ollama Go template, **omitting** the
   alternation guard. Render the same tokens the Jinja template emits:
   `[AVAILABLE_TOOLS]…[/AVAILABLE_TOOLS]`, `[INST]…[/INST]`,
   `[TOOL_CALLS]<name>[ARGS]<json-args>`, `[TOOL_RESULTS]…[/TOOL_RESULTS]`, and the
   EOS token after each assistant turn. Ollama exposes `.Messages` (with `.Role`,
   `.Content`, `.ToolCalls`), `.Tools`, and `.System`.
2. Add the `TEMPLATE """…"""` block to the Modelfile that `scripts/setup.sh`
   writes (alongside `FROM` / `PARAMETER`), then `ollama create devstral-q3`.
3. Re-apply on every model re-pull (setup.sh already recreates the model).

Bootstrap aids:
- `@huggingface/ollama-utils` `convertJinjaToGoTemplate` can generate a first-cut
  Go template from the GGUF's Jinja; then hand-remove the guard.
- Validate templates with
  [ollama-chat-template-test](https://github.com/eugene-kamenev/ollama-chat-template-test).

Trade-offs vs the proxy:
- **Pros:** no runtime hop, no extra service, no `uv` dependency; the fix lives in
  the model.
- **Cons:** the Go template must reproduce Devstral's tool-call format exactly --
  a subtle mismatch breaks tool calling *silently* (worse than a loud 500);
  ongoing template-maintenance burden as the upstream template evolves.

A heavier variant of the same idea: edit the embedded Jinja `tokenizer.chat_template`
directly with `gguf-new-metadata` (drop the guard lines) and `ollama create` from
the rewritten GGUF -- but that rewrites the full ~11.5 GB file, so the
Go-template-via-Modelfile route is preferred if we go this way.

**Adoption gate:** before switching off the proxy, replay the captured failing
payloads through the patched model *and* run a tool-calling smoke test, confirming
tool calls still parse and the 500s are gone.

## References

- [mistral-vibe#255](https://github.com/mistralai/mistral-vibe/issues/255) -- the upstream bug (open)
- [Unsloth Devstral GGUF discussion](https://huggingface.co/unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF/discussions/2) -- template workaround
