# /implement-feature

Implement the change I describe after this command, end to end.

1. Plan: read the relevant files and `docs/DECISIONS.md`. Write a plan of 3 to 6 lines with the files to change. Do not ask for approval unless a decision is genuinely mine to make.
2. Research only if needed: delegate to `warno-researcher` when the change depends on an upstream fact that `docs/ARCHITECTURE.md` does not record with a source URL. Otherwise skip research and say so.
3. Implement, keeping the invariants in `.cursor/rules/warno-project.mdc`. Add or update a case in `tests/entrypoint_test.sh` when wrapper behavior changes.
4. Validate: run `sh scripts/check_repo.sh`. Then launch `verifier`, and also `unraid-template-reviewer` if the template, Docker files, networking, paths, or install docs changed, in parallel. Give each the changed file list and the claim to check, and ask for the return shape in `.cursor/rules/agent-workflow.mdc`.
5. Fix what they report, re-run the check, and update `README.md`, `docs/ARCHITECTURE.md`, and `docs/DECISIONS.md` when behavior, verified facts, or decisions changed.
6. Report: what changed, which checks ran and passed, and what still needs a real Unraid test. Do not commit or push unless I ask.
