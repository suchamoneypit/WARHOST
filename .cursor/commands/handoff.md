# /handoff

Summarize the current state so a fresh chat can continue, and update the durable documentation.

1. Run `git status --short` and `git log --oneline -5`. List what is changed but not committed.
2. Write a handoff of under 400 words. Include what was done this session, what was verified (with the command or URL), what is unverified, and the exact next step. Also include these three lines, and spend any words past a short status only on them:
   - Leftover intent: anything the user asked that is not in the docs or the commit, including a list that stopped early. If there is none, write "None."
   - Do not redo: checks and upstream fetches already done, each with a command, URL, or `file:line`. The next chat must not repeat those.
   - Git state: branch, commit hash, and whether it has been pushed.
   Do not restate facts already in `docs/`. Point at the file instead.
3. Update the durable files only where something changed this session: new verified facts go in `docs/ARCHITECTURE.md`; new choices get a dated entry in `docs/DECISIONS.md`; goals or known issues go in `docs/ROADMAP.md`; install procedure changes go in `docs/INSTALL-UNRAID.md` and `README.md`. Leave `.cursor/` unchanged unless the workflow itself changed.
4. Do not commit. Tell me which files you updated and paste the handoff text so I can start a new chat with it. The rules and docs carry the rest.
