---
name: credential-review
description: Adversarial review of how the Eugen login and dedicated key are handled. Launches credential-reviewer. Reports only.
disable-model-invocation: true
---

# /credential-review

Adversarial review of how the Eugen login and dedicated key are handled. Do not modify files.

1. Launch `credential-reviewer` on the current tree. Ask for the return shape in `.claude/agents/credential-reviewer.md`. The accepted boundary is in that file: both form fields stay clear text, and the startup log may name only the last four characters of the key.
2. Report its findings, accepted items, and unverified items. Do not apply fixes.
