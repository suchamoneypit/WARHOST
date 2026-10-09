# /review-and-verify

Independently review and verify the current uncommitted changes, or the branch diff against `main` if the working tree is clean. Do not modify files.

1. Run `git status --short` and `git diff --stat` and list the changed files.
2. Launch in parallel, giving each the file list, a short diff summary, and the claim the change is meant to satisfy:
   - `verifier`, always.
   - `unraid-template-reviewer`, if any of `templates/`, `ca_profile.xml`, `Dockerfile`, `entrypoint-unraid.sh`, `README.md`, or `docs/INSTALL-UNRAID.md` changed. Ask it for structure, not field-wording comparison.
   - `docs-consistency`, if a name, default, description, port, path, image, or command changed. Ask for the short shape in its file. Skip it when the diff has no paired fact.
3. Merge their results into one report: defects to fix with `file:line`, checks that passed, and items that need a real Unraid server or credentials.
4. Propose fixes; apply them only if I ask.
