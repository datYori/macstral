"""Devstral chat-template alternation fix.

Devstral's GGUF Jinja template requires that "counted" messages -- `user`, and
`assistant` messages WITHOUT `tool_calls` -- strictly alternate user/assistant.
Tool-call assistant messages and `tool` results are skipped by that counter.
Mistral Vibe since v2.10.0 (which dropped consecutive user-message merging) can
emit two counted-user messages in a row -- e.g. when a turn is interrupted mid
tool-loop -- which makes the template raise a 500 (mistralai/mistral-vibe#255):

    Jinja Exception: After the optional system message, conversation roles must
    alternate user and assistant roles except for tool calls and results.

normalize() restores alternation by inserting one minimal filler turn of the
expected role wherever two counted messages of the same role would collide.
Clean conversations are returned unchanged (inserted == 0).
"""

# Filler content must be non-empty: the template raises on an assistant message
# that has neither content nor tool_calls.
FILLER = {"assistant": "(continuing)", "user": "(continue)"}


def is_counted(message):
    """True for messages the template counts toward role alternation."""
    role = message.get("role")
    return role == "user" or (role == "assistant" and not message.get("tool_calls"))


def normalize(messages):
    """Return (messages, inserted) with counted roles strictly alternating.

    `messages` is the OpenAI-style list. Non-counted messages (tool results,
    tool-call assistants, system) pass through untouched and in place.
    """
    out, count, inserted = [], 0, 0
    for message in messages:
        if not is_counted(message):
            out.append(message)
            continue
        expected = "user" if count % 2 == 0 else "assistant"
        if message.get("role") != expected:
            out.append({"role": expected, "content": FILLER[expected]})
            count += 1
            inserted += 1
        out.append(message)
        count += 1
    return out, inserted
