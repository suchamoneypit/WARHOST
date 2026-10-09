# /credential-review

Adversarial review of how the Eugen login and dedicated key are handled. Do not modify files.

1. Launch `credential-reviewer` on the current tree. Ask for the return shape in `.cursor/agents/credential-reviewer.md`. The accepted boundary is in that file and in `docs/DECISIONS.md`: both form fields stay clear text, and the startup log may name only the last four characters of the key.
2. Report its findings, accepted items, and unverified items. Do not apply fixes.
