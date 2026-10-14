---
name: project-help
description: Explain this repository's Cursor and Claude Code setup to a beginner and recommend a workflow for a described task.
disable-model-invocation: true
---

# /project-help

Explain this project's agent setup to a beginner and recommend a workflow for the task described after this command, if any.

1. Read `docs/AI-WORKFLOW.md` and list the files in `.claude/agents/`, `.claude/skills/`, `.cursor/commands/`, and `.cursor/rules/`. Do not restate them in full.
2. In under 300 words: which subagents exist and the one-line trigger for each; which commands exist and which tool runs them; which rules are always on (`CLAUDE.md` in both tools, `.cursor/rules/cursor-to-claude.mdc` in Cursor) and which attach only to certain files.
3. If a task was described, recommend the command or sequence, which tool should run it (Cursor or Claude Code), which subagents it involves and why, and the files likely to change. If the task is small, say no subagent is needed.
4. End with the single next action to take.
