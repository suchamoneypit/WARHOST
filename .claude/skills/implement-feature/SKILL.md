---
name: implement-feature
description: Implement a described change end to end, then run the check, align paired docs, and report. Run as /implement-feature followed by the change.
disable-model-invocation: true
---

# /implement-feature

Implement the change described after this command, end to end.

1. Plan. Read `docs/PROJECT-MAP.md`, the index at the top of `docs/DECISIONS.md`, and only the files and decision entries the change touches. Write a plan of 3 to 6 lines with the files to change. Ask only if a decision is genuinely the user's.
2. Research only if needed. Launch `warno-researcher` when the change depends on an upstream fact that `docs/ARCHITECTURE.md` does not record with a source URL. Otherwise say research was skipped.
3. Implement, keeping the protected values in `CLAUDE.md`. Add or update a case in `tests/entrypoint_test.sh` when wrapper behavior changes.
4. Run `sh scripts/check_repo.sh` and fix what fails.
5. If a name, default, description, port, path, image, or command changed, `rg` that exact token in `templates/`, `README.md`, and `docs/INSTALL-UNRAID.md`, and fix each pair that now disagrees.
6. Update `docs/ARCHITECTURE.md` and `docs/DECISIONS.md` (entry and index line) only when behavior, a verified fact, or a decision changed.
7. Report what changed, which checks ran and passed, and what still needs a real Unraid test. Do not commit or push. The `reviewer` runs once per batch before a commit, through `/review-and-verify`, not after each feature.
