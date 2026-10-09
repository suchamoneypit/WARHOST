# Cursor quickstart for this repository

A cheat sheet for working on this project with Cursor's Agent. It describes what is checked into `.cursor/`, who does what, and the normal path from a request to a GitHub pull request. Format facts below were checked against [cursor.com/docs/rules](https://cursor.com/docs/rules), [cursor.com/docs/subagents](https://cursor.com/docs/subagents), and [cursor.com/docs/skills](https://cursor.com/docs/skills) on 2026-10-09 with Cursor 3.21.18. Cursor's docs are not version-tagged, so re-check them when Cursor updates.

## What is in `.cursor/`

| Path | Kind | Loaded when |
| --- | --- | --- |
| `rules/agent-workflow.mdc` | Rule, generic | Every chat. How the agent works and when it delegates. |
| `rules/warno-project.mdc` | Rule, WARNO-specific | Every chat. Project facts, invariants, secrets, validation command. |
| `rules/unraid-template.mdc` | Rule, generic | Only when a template, profile, Dockerfile, entrypoint, or check script is in context. |
| `agents/warno-researcher.md` | Subagent, WARNO-specific | When the main agent launches it, or you type `/warno-researcher`. |
| `agents/unraid-template-reviewer.md` | Subagent, generic with a project-specifics paragraph | Same. |
| `agents/verifier.md` | Subagent, generic | Same. |
| `agents/docs-consistency.md` | Subagent, generic | Same. |
| `commands/*.md` | Slash commands | Only when you type `/<name>`. |

Rules are injected into the prompt. Subagents run in their own context window and return one final message. Commands are reusable prompts. Nothing in `.cursor/` runs on a timer or on every file save; a subagent runs only when the main agent delegates to it or you invoke it.

## The four subagents

| Agent | Purpose | Main agent uses it when | Call it yourself |
| --- | --- | --- | --- |
| `warno-researcher` | Fetches and labels upstream facts: Eugen's Docker Hub docs, the `eugensystems/warno` image config, Steam Workshop pages, scenario IDs from a subscribed mod's `Scenarios/` folder. Read-only. | A task depends on an upstream fact that `docs/ARCHITECTURE.md` does not record with a source, or that may have changed. | `/warno-researcher does Eugen's image still exec /server/entrypoint2.sh?` |
| `unraid-template-reviewer` | Reviews the template XML, CA profile, Dockerfile, entrypoint, networking statements, and install docs against `docs/UNRAID-TEMPLATE-GUIDE.md`. Read-only; reports `file:line`. | Any of those files changed. | `/unraid-template-reviewer review the uncommitted template changes` |
| `verifier` | Runs `sh scripts/check_repo.sh`, re-reads changed files against the claim, probes edge cases, reports Passed / Failed / Unverified. Does not fix. | A nontrivial change is marked done. | `/verifier confirm the entrypoint still rejects placeholder map IDs` |
| `docs-consistency` | Compares the facts this change altered (name, default, description, port, path, image, command) with the template, README, and install docs. Read-only; names the one sentence to fix. Does not reread untouched docs. | The functional edit is done and one of those facts changed, so a pair such as a template field description and the README may disagree. | `/docs-consistency the template field description changed; check the README pair` |

Cursor also ships built-in subagents (for example `explore` for codebase search, `bugbot` and `security-review` for diff review, `cursor-guide` for Cursor questions). The main agent may use those too; they are not part of this repository.

`warno-researcher`, `unraid-template-reviewer`, and `verifier` return findings as bullets with a source or `file:line`, affected files, commands run with results, and remaining uncertainty. `docs-consistency` returns only Consistent, Mismatches, and Skipped, in under 200 words. If you get a wall of text instead, ask for that shape.

## Routing rules

From `.cursor/rules/agent-workflow.mdc`:

- Research first only when an upstream fact is missing or stale. Skip it for wording, structure, or facts already recorded with a URL.
- Reviewer after changes to template, Docker, networking, paths, variables, or install docs. Skip for `.cursor/`, tests, workflow YAML. It checks structure; field wording belongs to `docs-consistency`.
- Verifier after any nontrivial implementation or any doc that makes testable claims. Skip for one-line edits the agent already checked by running the command.
- `docs-consistency` after a functional edit that changed a name, default, description, port, path, image, or command. Skip tests, CI, `.cursor/` edits, and wording no other file restates.
- Researcher before implementation when needed. `docs-consistency` next, and its sentences are applied before review. Reviewer and verifier then run in parallel. A small task uses none of them.

## Normal workflow

1. **Ask.** Describe the change, or use `/implement-feature <description>`.
2. **Plan.** The agent reads the relevant files and `docs/DECISIONS.md`, states a short plan, and proceeds unless a decision is yours.
3. **Research (if needed).** `warno-researcher` returns labeled facts and affected files.
4. **Implement.** Edits plus a test case in `tests/entrypoint_test.sh` when wrapper behavior changes.
5. **Align paired wording.** If a name, default, description, port, path, image, or command changed, `docs-consistency` compares that fact with the template, README, and install docs. Apply only the sentences it names.
6. **Check.** `sh scripts/check_repo.sh` (XML well-formedness, repository invariants, shell syntax, wrapper tests against a fake upstream).
7. **Review and verify.** `/review-and-verify`, or the agent launches `verifier` and, when relevant, `unraid-template-reviewer` in parallel. Fix, re-check.
8. **Record decisions.** `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, or `docs/ROADMAP.md` when behavior, a verified fact, or a goal changed. The consistency check does not write those.
9. **Commit on `dev`.** You decide when to commit. The agent commits that work on `dev` and pushes `origin/dev`. If the checkout is `main`, it switches to `dev` first. Community Apps and the raw template URL read `main`, so commits on `dev` do not change the Apps listing or the Docker image.
10. **Publish to `main` only when you ask.** Say explicitly that you want the accumulated work on `main`. The agent then merges `dev` into `main` and pushes `origin/main`. The `Check repository` workflow runs `scripts/check_repo.sh` on every PR and on `main`. A `main` push that changes `Dockerfile`, `entrypoint-unraid.sh`, or the rebuild workflow also triggers **Rebuild WARNO image**, which publishes `ghcr.io/suchamoneypit/warno-unraid:latest`. Wording and template-only pushes update the Apps listing and do not rebuild that image. The agent will not push to `main`, force-push, or merge on its own.

## Starting a fresh chat without losing knowledge

Long chats slow down and cost more context. The project is designed so that a new chat starts informed:

- The two always-on rules load automatically. The template rule loads when you open a template or wrapper file.
- Durable facts are in `docs/`, not in chat history. Before closing a chat, run `/handoff`. It updates those docs and prints a paste of under 400 words: what changed, what was checked, what is still open, the next step, leftover intent, sources the next chat must not fetch again, and git state. It points at `docs/` instead of restating them.
- To carry a specific thread over, mention the old chat with `@Chats` in the new one, or use Cursor's fork-chat action to continue from a chosen message. In the CLI, `/summarize` compacts the current chat in place. Cursor also compacts old turns automatically.
- Memories and Notepads are not in Cursor's current docs; do not rely on them.

## Slash commands

Project commands in `.cursor/commands/` (name = file name):

| Command | Use it when |
| --- | --- |
| `/project-help` | You are unsure which workflow or agent fits, or you want the setup explained. |
| `/unraid-template-installscript` | You want the Unraid terminal command that downloads this template before it is in Community Applications. |
| `/first-unraid-install` | You are doing the first install of this container on Unraid and want to be walked through `docs/INSTALL-UNRAID.md` with live checks. |
| `/implement-feature <what>` | A change that touches code, template, or docs and should end with checks and updated docs. |
| `/review-and-verify` | You want an independent review of uncommitted changes before committing. |
| `/handoff` | You are about to close a chat or hand the work to someone else. |

Useful built-ins (from Cursor's docs; the editor and the CLI differ slightly): `/plan` to switch to Plan mode, `/create-rule`, `/create-subagent`, `/create-skill`, `/review` for a diff review, `/summarize` (CLI) to compact context. Cursor's docs now treat skills (`.cursor/skills/<name>/SKILL.md`) as the successor to commands and offer `/migrate-to-skills`; the commands above are small enough that migrating them is optional.

## What is generic and what is WARNO-specific

Generic, ready to copy into another game-server template repository: `rules/agent-workflow.mdc`, `rules/unraid-template.mdc`, `agents/unraid-template-reviewer.md` (replace its project-specifics paragraph), `agents/verifier.md`, `agents/docs-consistency.md`, the commands in `.cursor/commands/` (rename `first-unraid-install` targets), `docs/UNRAID-TEMPLATE-GUIDE.md`, `scripts/print_template_fetch.sh`, and this file's structure.

WARNO-specific: `rules/warno-project.mdc`, `agents/warno-researcher.md`, `README.md`, `docs/INSTALL-UNRAID.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/ROADMAP.md`, the template, the wrapper, samples, and tests.
