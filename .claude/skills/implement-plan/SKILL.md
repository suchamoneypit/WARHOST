---
name: implement-plan
description: Implement a plan file written in Cursor (usually .cursor/plans/*.plan.md or ~/.cursor/plans/*.plan.md), run the check, and report without committing. Run as /implement-plan followed by the plan path.
disable-model-invocation: true
---

# /implement-plan

Implement the plan at the path given after this command. If no path is given, list `.cursor/plans/*.plan.md` and `~/.cursor/plans/*.plan.md` by modification time and ask which one.

1. Read the plan. Its todo list in the frontmatter is the scope. Do not edit the plan file.
2. Run `git status --short`. If the tree is dirty with changes the plan does not explain, list them and ask before continuing.
3. Implement the todos in order, reading only the files each one names plus what `rg` finds. Keep the protected values in `CLAUDE.md`.
4. Run `sh scripts/check_repo.sh` after the last code change and fix what fails.
5. Report: each todo as done, skipped (with the reason), or blocked; the check result; what needs a real Unraid server. Do not commit or push. Cursor commits.
