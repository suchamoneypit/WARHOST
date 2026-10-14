# AI workflow: Cursor and Claude Code

This repository is worked on with two tools: Cursor's Agent and Claude Code (the extension inside Cursor, or the `claude` CLI). Both read the same instruction files, so there is one copy of each rule, subagent, and command. Format facts come from Cursor's [rules](https://cursor.com/docs/rules.md), [subagents](https://cursor.com/docs/subagents.md), and [skills](https://cursor.com/docs/skills.md) pages and from `claude --help` (Claude Code 2.1.287 and 2.1.296).

## Who does what

- **Cursor** plans (Plan mode), previews the WebUI with Design Mode (`/webui`), reviews, and commits on `dev`. It can also use non-Claude models, which gives a genuinely different second opinion.
- **Claude Code** implements a Cursor plan (`/implement-plan <path>`), takes a focused bug, and runs reviews Cursor hands it. It never commits, pushes, or merges; `.claude/settings.json` denies those commands.
- One tool edits the working tree at a time. The next one starts from `git status` and `git diff`. There is no handoff file.

## Files

| Path | Read by | Purpose |
| --- | --- | --- |
| `CLAUDE.md` | Both, every chat | Project facts, protected values, secrets, tool roles, subagent triggers, the check command |
| `.claude/agents/*.md` | Both | Subagents: `reviewer`, `warno-researcher`, `credential-reviewer`, `workshop-mod-reader` |
| `.claude/skills/*/SKILL.md` | Both | Slash commands, run only when typed (`disable-model-invocation: true`) |
| `.claude/settings.json` | Claude Code | Denies commit, push, merge, rebase, hard reset, and tag |
| `.cursor/rules/cursor-to-claude.mdc` | Cursor, every chat | When Cursor hands work to Claude, on which model, and how often |
| `.cursor/rules/unraid-template.mdc` | Cursor, when a template or wrapper file is open | Short Unraid template conventions |
| `.cursor/commands/webui.md`, `ask-claude.md` | Cursor | Commands that need Cursor's browser or call Claude |
| `scripts/ask_claude.sh` | Cursor agents | Runs `claude -p` in `review` (read-only) or `edit` mode and logs the call |
| `docs/PROJECT-MAP.md` | Both, first | File roles, the start-up flow, and where each topic is documented |

## Commands

| Command | Use it when |
| --- | --- |
| `/implement-feature <what>` | A change to code, template, or docs that should end with the check and updated docs |
| `/implement-plan <path>` | Claude Code implements a plan Cursor wrote (`~/.cursor/plans/` or `.cursor/plans/`) |
| `/review-and-verify` | Before committing a batch. Runs `reviewer`; from Cursor it also asks Claude in parallel |
| `/slop-review` | A rare, long review of everything that ships. Start a new Cursor chat on your strongest model; Claude Opus reviews in parallel |
| `/credential-review` | An adversarial review of the Eugen login and key handling |
| `/workshop-mods` | Compare the local Steam Workshop library with the README |
| `/map-previews` | Extract map pictures from a local WARNO install into `webui/previews/` |
| `/unraid-script` | Print the Unraid terminal commands for `main`, `dev`, and a clean slate |
| `/publish` | Cursor only, on an explicit request: merge `dev` into `main` |
| `/project-help` | You are unsure which workflow fits a task |
| `/webui` | Cursor only: serve this checkout's WebUI beside the chat |
| `/ask-claude <task>` | Cursor only: hand one task from the policy file to Claude by hand |

## Cursor calling Claude

`.cursor/rules/cursor-to-claude.mdc` has a settings block. Each task has `when` (`auto`, `ask`, `suggest`, `off`), a model, an effort (`low`, `medium`, `high`, `xhigh`, `max`), a mode, and a turn limit, and per-chat limits cap Sonnet and Opus calls. Routine Sonnet calls use `medium`. The Opus slop review uses `high`. The defaults:

- A bug whose first fix fails goes to Sonnet for a root-cause read, at most twice per chat.
- `/review-and-verify` and each new plan get a Sonnet second look.
- `/slop-review` runs Opus in the background, independent of Cursor's own pass, and the two reports are merged.
- Claude implementing a whole plan is off; do that in the Claude Code panel.

Each call appends one line to `.cursor/claude-calls.log` (gitignored) with the task, model, effort, duration, turns, tokens, and session id. `claude --resume <session id>` opens that call in Claude Code to continue it. A call starts with about 11k tokens of Claude's own context before it reads a file.

One-time setup: run `claude install` from the extension's binary so `~/.local/bin/claude` exists (the wrapper falls back to the extension's copy when it does not), and open Claude Code once in this folder and accept the trust prompt so `.claude/settings.json` allow rules apply.

## Keeping token use down

- Start a new chat per task. Durable knowledge is in `docs/` and git, not in the chat. In Claude Code, `/clear` between tasks.
- Agents read `docs/PROJECT-MAP.md` and the `docs/DECISIONS.md` index first, then `rg`, and read only the sections that hit.
- A small change needs no subagent; `sh scripts/check_repo.sh` is enough. `reviewer` runs once per batch.
- Keep Claude Code on Sonnet by default. Use Opus for `/slop-review` or a hard bug; it uses the Pro limit much faster.
- When behavior changes, update `docs/ARCHITECTURE.md` and add a `docs/DECISIONS.md` entry and index line in the same change, so the next agent does not have to rediscover it.

## Clean slate on Unraid

`/unraid-script` prints a third command, `sh scripts/print_template_fetch.sh --clean --branch main --branch dev`. It stops and removes the `WARHOST` and `WARHOST-dev` containers, drops those names from `/var/lib/docker/unraid-autostart`, deletes the user-template files and the two private files under `/boot/config/plugins/community.applications/private/suchamoneypit/`, and removes each container's settings folder `/mnt/user/appdata/warno/<port>/settings`. That folder holds the login and key. A folder still mounted by another container is left in place. The image is removed only when no container is still using it.

## Publishing the image

Before merging `dev` into `main`, set `<Repository>` in `templates/warhost.xml` back to `ghcr.io/suchamoneypit/warhost:latest`. The publish procedure is the `/publish` command, and it does that. A fork repeats these steps once the files are on `main`:

1. In the GitHub repository settings, enable Issues.
2. Under Actions, allow GitHub Actions, and set workflow permissions to read and write.
3. Run the **Rebuild WARHOST image** workflow.
4. Open the package `warhost` and set its visibility to Public. Unraid cannot pull a private package.

Then install the template and confirm the container stays up, the key is only in that server's settings files, and the preset Hesse map is the running scenario. Community Apps reads `main`. A first submission needs a public repository, the MIT `LICENSE` at the root, `ca_profile.xml` with a non-empty Profile, and `templates/warhost.xml`. Open [https://ca.unraid.net/submit](https://ca.unraid.net/submit), run Validate, then Scan, and submit when the scan is clean. The help pages are [submission help](https://ca.unraid.net/submit/help), [repository XML](https://ca.unraid.net/submit/help/repository-xml), and [repository information XML](https://ca.unraid.net/submit/help/repository-info-xml).

## Reusing this setup

Generic, ready to copy into another game-server template repository: `.cursor/rules/unraid-template.mdc`, `.claude/agents/reviewer.md` (replace its project specifics), the skills except `credential-review`, `workshop-mods`, and `map-previews` (replace the project-specifics section of `slop-review`), `scripts/ask_claude.sh`, `.cursor/rules/cursor-to-claude.mdc`, `docs/UNRAID-TEMPLATE-GUIDE.md`, and `scripts/print_template_fetch.sh`. `CLAUDE.md` mixes the workflow with WARNO facts; keep its structure and replace the facts.
