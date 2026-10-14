# /ask-claude

Hand one task to Claude Code through `claude -p` and show its report. The text after this command is a task name from `.cursor/rules/cursor-to-claude.mdc` (`stuck_bug`, `pre_commit_review`, `plan_second_look`, `slop_review`, `implement_plan`), optionally followed by details. With no task name, treat the text as a `stuck_bug`-style review question.

1. Look up that task's `model`, `effort`, `mode`, and `max_turns` in `.cursor/rules/cursor-to-claude.mdc`. A manual call ignores `when`, but still respects `enabled` and the per-chat limits.
2. Build a short prompt: the details given, the relevant paths, and the claim or question. For `slop_review`, the prompt is `/slop-review`. For `pre_commit_review`, it is `/review-and-verify` plus the changed file list. For `implement_plan`, it is `/implement-plan <path>`.
3. Run from the repository root with `full_network` permission:

   sh scripts/ask_claude.sh --task <name> --mode <mode> --model <model> --effort <level> --max-turns <n> "<prompt>"

4. Show the report verbatim, then one line with your own take on which findings matter. Do not apply fixes unless asked.
