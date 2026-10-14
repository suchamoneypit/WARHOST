# Project map

A one-page orientation for agents and contributors. Read this first, then `rg` for the term you need. Protected values and working rules are in `CLAUDE.md`. Recent changes are `git log --oneline -15`; each commit subject is a one-sentence summary.

## Start-up flow

```text
Unraid form (templates/warhost.xml)
  -> entrypoint-unraid.sh, PID 1
       checks the Game Port and locks the settings folder
       writes login.ini; seeds variables.ini and params_for_ai.json when missing
       resolves bare Workshop ids in ModList to id/Version (DepotDownloader, Config.ini only)
       starts webui/launch.sh when WEB_UI=true (fail-open, page on Game Port + 1000)
       runs /server/entrypoint2.sh (Eugen) in its own session
  <- SIGUSR1 from the WebUI's Save and restart: the wrapper re-execs itself
```

## Files

| Path | Role |
| --- | --- |
| `templates/warhost.xml` | Unraid template: seven form fields, host networking, `<Repository>` `:latest` on `main` and `:dev` on `dev` |
| `ca_profile.xml`, `icon.png` | Community Apps profile and icon |
| `Dockerfile` | `FROM eugensystems/warno:latest`, pinned DepotDownloader, copies the wrapper and `webui/` |
| `entrypoint-unraid.sh` | The wrapper (about 1,000 lines): validation, settings writes, port check, Workshop versions, WebUI hook, restart supervisor |
| `webui/server.py` | WebUI HTTP server; signals the wrapper for Save and restart |
| `webui/lobby.py` | Validates a save and replaces `variables.ini` (and `params_for_ai.json` for PvE). Never reads `login.ini` |
| `webui/index.html` | The page |
| `webui/launch.sh` | Starts the page, drops to `warhost-web`, prints the listening line |
| `webui/scenarios.json`, `webui/make_catalog.py` | Map and mod catalog, built from the README tables |
| `samples/` | Placeholder shapes of the three settings files |
| `tests/entrypoint_test.sh`, `webui/test_page.sh` | Wrapper and page tests against fakes; never start the real server |
| `scripts/check_repo.sh` | The one check to run: XML, invariants, syntax, both test suites |
| `scripts/print_template_fetch.sh` | Prints the Unraid terminal command that downloads the template (`--branch`, `--private`, `--clean`) |
| `scripts/list_workshop_mods.py` | Reads the local Steam Workshop folder and diffs it with the README |
| `scripts/extract_map_previews.py` | Copies map pictures from a local WARNO install into gitignored `webui/previews/` |
| `scripts/upstream_digest.py`, `scripts/next_version.py`, `scripts/release_notes.py` | Eugen digest, release number, release notes |
| `scripts/ask_claude.sh` | Cursor's bridge to `claude -p` |
| `.github/workflows/` | `check-repo.yml`, `rebuild-image.yml` (`:latest` from `main`, `:dev` from `dev`), `release.yml` (tags and releases each `main` push) |
| `CLAUDE.md`, `.claude/`, `.cursor/` | Agent instructions, subagents, skills, and Cursor-only rules and commands. See `docs/AI-WORKFLOW.md` |

## Where each topic is documented

| Topic | Where |
| --- | --- |
| Install steps, form fields, troubleshooting | `docs/INSTALL-UNRAID.md`, `README.md` Install |
| Scenario IDs and workshop mods | `README.md` tables (also the WebUI catalog source) |
| How a start, the WebUI, networking, and Workshop versions behave | `docs/ARCHITECTURE.md` |
| Why something is the way it is | `docs/DECISIONS.md` index, then the entry |
| Dated reads, measurements, operator observations | `docs/EVIDENCE.md` |
| Goals and known issues | `docs/ROADMAP.md` |
| Unraid template conventions, any game | `docs/UNRAID-TEMPLATE-GUIDE.md` |
| Publishing to `main` and version numbers | `.claude/skills/publish/SKILL.md`, `docs/ARCHITECTURE.md` Images and releases |
| Agent setup for Cursor and Claude Code | `docs/AI-WORKFLOW.md` |
