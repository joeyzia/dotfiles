#!/usr/bin/env python3
"""PostToolUse guard: block Go edits that explain a decision in a source comment.

Fires only on comment lines that carry decision/justification language — the
"why this approach, why not the alternative, what used to be true" smell. Normal
one-line doc comments, swagger (// @...) blocks, and //go: directives do not match.
Exit 2 feeds the message back to Claude so it revises the edit in-session.
"""
import json
import re
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

ti = data.get("tool_input", {}) or {}
fp = ti.get("file_path", "") or ""
if not fp.endswith(".go"):
    sys.exit(0)

chunks = []
if isinstance(ti.get("content"), str):
    chunks.append(ti["content"])
if isinstance(ti.get("new_string"), str):
    chunks.append(ti["new_string"])
for e in ti.get("edits", []) or []:
    if isinstance(e, dict) and isinstance(e.get("new_string"), str):
        chunks.append(e["new_string"])

text = "\n".join(chunks)
if not text.strip():
    sys.exit(0)

decision = re.compile(
    r"\b(because|so that|so it |so we |so the |rather than|otherwise|the reason|"
    r"used to|what breaks|in order to|this is why|which is why|we do this|"
    r"deliberately|intentionally|on purpose)\b",
    re.I,
)

flags = []
for ln in text.split("\n"):
    s = ln.strip()
    if not s.startswith("//"):
        continue
    if s.startswith("// @") or s.startswith("//go:") or s.startswith("//nolint"):
        continue
    if decision.search(s):
        flags.append(s[:110])

if not flags:
    sys.exit(0)

out = [
    "COMMENT-STYLE hook: this edit to %s adds source comments that argue a decision." % fp,
    "House rule: never explain a decision in source — why this approach, why not the",
    "alternative, what used to be true. That belongs in the commit message / PR body.",
    "Default to NO comment. Exported items get one line (two max). Unexported funcs/types",
    "and tests get none. Remove the flagged comments before continuing:",
]
for s in flags[:8]:
    out.append("  - " + s)
sys.stderr.write("\n".join(out) + "\n")
sys.exit(2)
