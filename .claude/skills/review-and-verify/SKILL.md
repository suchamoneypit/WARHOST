---
name: review-and-verify
description: Review the current uncommitted changes, or the branch diff against main when the tree is clean, before a commit. Launches the reviewer subagent and, from Cursor, a Claude second opinion. Reports only.
disable-model-invocation: true
---

# /review-and-verify

Review the current uncommitted changes, or the branch diff against `main` if the working tree is clean. Do not modify files.

1. Run `git status --short` and `git diff --stat` and list the changed files.
2. Launch `reviewer` with the file list, a two-line diff summary, and the claim the change is meant to satisfy.
3. In Cursor only: when `.cursor/rules/cursor-to-claude.mdc` sets `pre_commit_review` to `auto`, start that Claude call in the background at the same time with the same file list and claim. Skip this step when running in Claude Code.
4. Merge the results into one report: defects to fix with `file:line`, doc mismatches with the sentence to write, checks that passed, and items that need a real Unraid server or credentials. Mark a finding that only Claude raised.
5. Propose fixes. Apply them only when asked.
