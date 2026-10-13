# WARHOST

An Unraid template plus a settings wrapper around Eugen Systems' official `eugensystems/warno` dedicated-server image. `entrypoint-unraid.sh` writes `login.ini`, `variables.ini`, and `params_for_ai.json` into `/server/settings`, then runs `/server/entrypoint2.sh`. Eugen's server launch arguments stay in their image. `webui/` is the lobby editor. Cursor and Claude Code both read this file.

## Look things up before reading widely

1. `docs/PROJECT-MAP.md`: what each file does, the start-up flow, and where each topic is documented.
2. `git log --oneline -15` for recent changes; `git status` and `git diff` for work in progress.
3. The index at the top of `docs/DECISIONS.md` for why something is the way it is. Open only the entry you need.
4. `rg` the term and read only the sections it hits. Do not read `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `README.md`, or `docs/INSTALL-UNRAID.md` end to end unless the task edits that file throughout.

## Do not change unless the task asks for it

Server settings and the fixed `variables.ini` seed (`WARHOST - default server name`, Map `_2x2_Hesse_2vs2_CONQ`, 4/2/2 slots, Conquest, no workshop mods), launch arguments, template defaults (`EXPOSEDPORT` `10400`; the lobby name, map, slots, combat rule, and workshop mods stay off the Docker form), host networking, the settings path `/server/settings`, the host folder `/mnt/user/appdata/warno/10400/settings`, image build logic, and the image names `ghcr.io/suchamoneypit/warhost:latest` (published from `main`) and `ghcr.io/suchamoneypit/warhost:dev` (the dev template). The Red Dragon example stays `RDPort_JungleLaw_2v2_CONQ` with `3811913066` in the README.

## Evidence

- Cite a URL for Eugen, Docker Hub, Steam, or Unraid claims. Anything not fetched this session is "unverified" or "repository statement".
- `10400` is this repo's choice; Eugen's docs use a placeholder port. Eugen does not document the `Map` key for workshop maps; the `RDPort_*` scenario IDs are the file names in the mod's `Scenarios/` folder (procedure in `docs/INSTALL-UNRAID.md`).
- Local checks prove XML well-formedness and wrapper behavior only. Unraid acceptance and remote connectivity need a real server. In every summary, separate what was checked locally from what needs a real deployment.

## Secrets

Eugen logins, dedicated keys, real `login.ini`, and real `settings/` folders never enter git, samples, issues, or chat. The only placeholders are `YOUR_EUGEN_LOGIN_HERE` and `YOUR_EUGEN_DEDICATED_KEY_HERE`. A key that reached git history is compromised even after deletion.

## Tool roles

- Cursor plans, previews the WebUI, and commits. When the user asks to commit, commit on `dev` and push `origin/dev`, switching from `main` first. Asking to commit is not permission to update `main`.
- Claude Code edits files and stops. It never runs `git commit`, `git push`, `git merge`, `git rebase`, or `git reset --hard`; `.claude/settings.json` denies them. Read-only git is fine. Offer a commit message as text if useful.
- One tool edits the tree at a time. The next one starts from `git status` and `git diff`.
- When Cursor hands work to Claude through `claude -p` is set in `.cursor/rules/cursor-to-claude.mdc`.

## Subagents

They live in `.claude/agents/` and both tools load them. Each starts with an empty context, so the prompt carries the task, the file list, and the claim to check. Hold the answer to the return shape in its file and bring back only what changes a decision.

- `reviewer`: once per batch of changes, before a commit, or through `/review-and-verify`. A small change you already checked with `sh scripts/check_repo.sh` needs none.
- `warno-researcher`: the task depends on an upstream fact (image entrypoint, settings keys, ports, mod or map IDs, key process) that `docs/ARCHITECTURE.md` does not record with a source URL, or that may have changed.
- `credential-reviewer`: `/credential-review`, or a change writes, logs, templates, or documents the Eugen login, dedicated key, or `login.ini`.
- `workshop-mod-reader`: `/workshop-mods`, or a refresh of workshop versions and scenario IDs from the local Steam library.

## Working rules

- Check `git status`, read a file before editing it, implement, run the check, summarize. Ask the user only for decisions that are theirs.
- Template and wrapper conventions: `.cursor/rules/unraid-template.mdc`, with sources in `docs/UNRAID-TEMPLATE-GUIDE.md`.
- Add or update a case in `tests/entrypoint_test.sh` when wrapper behavior changes.
- Update `README.md` and `docs/` in the same change when behavior, decisions, or install steps change. A new decision gets an entry and an index line in `docs/DECISIONS.md`.
- After any change to the template, wrapper, tests, or checks, run `sh scripts/check_repo.sh`. Tests never start the real server. Never claim a check passed unless it ran in this session.

## Publishing

Community Apps reads `<TemplateURL>` on `main`. Image rebuilds publish `:latest` from `main` and `:dev` from `dev`. Update `main` only when the user explicitly asks to publish; the procedure is the `publish` skill, and it sets the template `<Repository>` back to `:latest` before the merge. Do not force-push, deploy, or publish images without that request.
