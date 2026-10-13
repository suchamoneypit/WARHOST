#!/bin/sh
# Hand one task from a Cursor agent to Claude Code in print mode and print its report.
# Settings for when and how often to call this live in .cursor/rules/cursor-to-claude.mdc.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

exec python3 - "$ROOT" "$@" << 'PY'
import datetime
import glob
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import time

root = pathlib.Path(sys.argv[1])
usage = (
    "usage: sh scripts/ask_claude.sh --task NAME --mode review|edit [--model M] [--max-turns N]\n"
    "                                [--out FILE] [--allow-dirty] PROMPT\n"
    "\n"
    "review: read-only tools, never edits.\n"
    "edit:   may edit files; refuses on a dirty tree unless --allow-dirty.\n"
    "Prints Claude's report (or writes it to --out) and appends one line to\n"
    ".cursor/claude-calls.log. ASK_CLAUDE_BIN overrides the claude binary."
)

READ_TOOLS = [
    "Read", "Grep", "Glob",
    "Bash(git status)", "Bash(git status *)",
    "Bash(git diff)", "Bash(git diff *)",
    "Bash(git log *)", "Bash(git show *)",
    "Bash(git rev-parse *)", "Bash(git branch --show-current)",
    "Bash(rg *)", "Bash(sh -n *)", "Bash(head *)", "Bash(tail *)", "Bash(wc *)",
    "Bash(sh scripts/check_repo.sh)", "Bash(sh scripts/check_repo.sh *)",
]
EDIT_TOOLS = READ_TOOLS + ["Edit", "Write"]
APPEND = {
    "review": (
        "A Cursor agent called you non-interactively; nobody can answer questions. "
        "Subagents are not available here: when a skill says to launch one, do its work yourself. "
        "Read-only: do not edit files. Unless the prompt or skill sets its own report format, "
        "return short bullets with file:line evidence, then what you could not check, under 500 words."
    ),
    "edit": (
        "A Cursor agent called you non-interactively; nobody can answer questions. "
        "Subagents are not available here: when a skill says to launch one, do its work yourself. "
        "You may edit files. Never commit, push, or merge. "
        "End with the changed files, the result of sh scripts/check_repo.sh, and anything left undone."
    ),
}


def die(message, code=1):
    print(f"ask_claude: {message}", file=sys.stderr)
    sys.exit(code)


args = sys.argv[2:]
opts = {"task": None, "mode": None, "model": "sonnet", "max-turns": "20", "out": None}
allow_dirty = False
prompt = None
index = 0
while index < len(args):
    arg = args[index]
    if arg in ("-h", "--help"):
        print(usage)
        sys.exit(0)
    if arg == "--allow-dirty":
        allow_dirty = True
        index += 1
        continue
    if arg.startswith("--") and arg[2:] in opts:
        if index + 1 >= len(args):
            die(f"{arg} needs a value\n{usage}", 2)
        opts[arg[2:]] = args[index + 1]
        index += 2
        continue
    if arg.startswith("-") or prompt is not None:
        die(f"unexpected argument: {arg}\n{usage}", 2)
    prompt = arg
    index += 1

if not opts["task"] or not re.fullmatch(r"[a-z][a-z0-9_]*", opts["task"]):
    die(f"--task must be a lowercase name such as stuck_bug\n{usage}", 2)
if opts["mode"] not in APPEND:
    die(f"--mode must be review or edit\n{usage}", 2)
if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", opts["model"]):
    die("--model must be an alias such as sonnet or opus, or a full model name", 2)
if not opts["max-turns"].isdigit() or int(opts["max-turns"]) < 1:
    die("--max-turns must be a positive number", 2)
if not prompt:
    die(f"a prompt is required\n{usage}", 2)

claude = os.environ.get("ASK_CLAUDE_BIN") or shutil.which("claude")
if not claude:
    bundled = glob.glob(os.path.expanduser(
        "~/.cursor/extensions/anthropic.claude-code-*/resources/native-binary/claude"))
    bundled.sort(key=lambda p: [int(n) for n in re.findall(r"\d+", p.split("claude-code-")[1].split("/")[0])])
    claude = bundled[-1] if bundled else None
if not claude:
    die("claude was not found. Run the Claude Code extension's binary with `install`, or set ASK_CLAUDE_BIN.")

if opts["mode"] == "edit" and not allow_dirty:
    dirty = subprocess.run(["git", "status", "--porcelain"], cwd=root, capture_output=True, text=True).stdout
    if dirty.strip():
        die("edit mode needs a clean tree so Claude's changes are their own diff. Commit or stash first, or pass --allow-dirty.")

tools = EDIT_TOOLS if opts["mode"] == "edit" else READ_TOOLS
command = [
    claude, "-p",
    "--model", opts["model"],
    "--max-turns", opts["max-turns"],
    "--output-format", "json",
    "--permission-mode", "acceptEdits" if opts["mode"] == "edit" else "dontAsk",
    "--allowedTools", *tools,
    "--append-system-prompt", APPEND[opts["mode"]],
]
if opts["mode"] == "review":
    command += ["--disallowedTools", "Edit", "Write", "NotebookEdit"]
command += ["--", prompt]

started = time.time()
proc = subprocess.run(command, cwd=root, capture_output=True, text=True)
seconds = round(time.time() - started)

try:
    data = json.loads(proc.stdout)
except json.JSONDecodeError:
    data = {}
result = data.get("result") or ""
status = data.get("subtype") or f"exit{proc.returncode}"
usage_data = data.get("usage") or {}
input_tokens = sum(usage_data.get(k) or 0 for k in
                   ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"))
log_line = " ".join([
    datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
    f"task={opts['task']}", f"model={opts['model']}", f"mode={opts['mode']}",
    f"status={status}", f"seconds={seconds}", f"turns={data.get('num_turns', 0)}",
    f"input_tokens={input_tokens}", f"output_tokens={usage_data.get('output_tokens') or 0}",
    f"session={data.get('session_id', '-')}",
])
log_path = root / ".cursor" / "claude-calls.log"
log_path.parent.mkdir(exist_ok=True)
with log_path.open("a", encoding="utf-8") as log:
    log.write(log_line + "\n")

if proc.returncode != 0 or data.get("is_error") or not result:
    detail = result or proc.stderr.strip()[-2000:] or "no output"
    die(f"Claude call failed ({status}): {detail}")

if opts["out"]:
    pathlib.Path(opts["out"]).write_text(result + "\n", encoding="utf-8")
    print(f"ask_claude: wrote {opts['out']} ({status}, {seconds}s, session {data.get('session_id', '-')})")
else:
    print(result)
    print(f"\n[claude {opts['model']} {status}, {seconds}s, session {data.get('session_id', '-')}]")
PY
