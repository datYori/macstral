"""Unit tests for scripts/normalize.py (Devstral role-alternation repair).

Run via 'just test' (or: uv run tests/normalize_test.py). Pure stdlib, no daemon.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
from normalize import is_counted, normalize  # noqa: E402


def first_break(messages):
    """Index of the first message violating counted-role alternation, or None.

    Mirrors Devstral's template guard so the tests assert the same thing the
    model's template does.
    """
    idx, brk = 0, None
    for i, m in enumerate(messages):
        if is_counted(m):
            if (m["role"] == "user") != (idx % 2 == 0) and brk is None:
                brk = i
            idx += 1
    return brk


fails = 0


def check(name, cond):
    global fails
    print(("ok   " if cond else "FAIL ") + name)
    if not cond:
        fails += 1


def tc(name, args="{}"):
    return {"id": name, "type": "function", "function": {"name": name, "arguments": args}}


# 1. Clean alternating conversation is returned untouched.
clean = [
    {"role": "user", "content": "a"},
    {"role": "assistant", "content": "b"},
    {"role": "user", "content": "c"},
]
out, ins = normalize(clean)
check("clean: 0 inserts", ins == 0)
check("clean: unchanged", out == clean)
check("clean: no break", first_break(out) is None)

# 2. Two consecutive user messages (interrupt-then-resend, no tools).
dup = [{"role": "user", "content": "a"}, {"role": "user", "content": "b"}]
check("dup: break before", first_break(dup) is not None)
out, ins = normalize(dup)
check("dup: 1 insert", ins == 1)
check("dup: assistant filler inserted between", out[1]["role"] == "assistant")
check("dup: no break after", first_break(out) is None)

# 3. The real captured shape: interrupt mid tool-loop, then a new user message.
real = [
    {"role": "system", "content": "s"},
    {"role": "user", "content": "u1"},
    {"role": "assistant", "content": "a1"},
    {"role": "user", "content": "u2"},
    {"role": "assistant", "content": "", "tool_calls": [tc("read")]},
    {"role": "tool", "tool_call_id": "read", "content": "r1"},
    {"role": "assistant", "content": "", "tool_calls": [tc("grep")]},
    {"role": "tool", "tool_call_id": "grep", "content": "r2"},
    {"role": "user", "content": "u3"},
]
check("real: break before", first_break(real) is not None)
out, ins = normalize(real)
check("real: 1 insert", ins == 1)
check("real: no break after", first_break(out) is None)
check(
    "real: tool/tool-call msgs preserved",
    [m for m in out if not is_counted(m)] == [m for m in real if not is_counted(m)],
)

# 4. Proper tool flow (assistant text after the tool result) needs no repair.
good = [
    {"role": "user", "content": "u1"},
    {"role": "assistant", "content": "", "tool_calls": [tc("read")]},
    {"role": "tool", "tool_call_id": "read", "content": "r"},
    {"role": "assistant", "content": "done"},
    {"role": "user", "content": "u2"},
]
out, ins = normalize(good)
check("tool-flow: 0 inserts", ins == 0)
check("tool-flow: unchanged", out == good)

sys.exit(1 if fails else 0)
