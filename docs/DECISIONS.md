# Decisions

Durable choices for this repository. Dates are the commit date or the day the decision was recorded.

## 2026-10-09 — Wrap Eugen's image

**Decision:** `entrypoint-unraid.sh` writes settings and execs `/server/entrypoint2.sh`. This repo does not copy Eugen's server launch arguments.

**Rationale:** Game updates should come from `eugensystems/warno`. The wrapper only supplies the Unraid form. Recorded in commit `b8466df`.

## 2026-10-09 — Host networking

**Decision:** The template uses `<Network>host</Network>` and does not publish a Docker port. Operators forward `EXPOSEDPORT` as TCP and UDP. The default port is `10400`.

**Rationale:** Eugen recommends host networking and requires both protocols. Unraid host networking does not show a port mapping. `10400` is this template's default, not a port named by Eugen.

## 2026-10-09 — Form-written settings

**Decision:** `WRITE_CONFIG` defaults to true and rewrites `login.ini`, `variables.ini`, and `params_for_ai.json` on each start. Set it false only for hand-edited files.

**Rationale:** The Unraid form is the supported way to configure a server. Hand edits would otherwise be mistaken for the source of truth. Recorded in commit `b8466df`.

## 2026-10-09 — Keys stay out of git

**Decision:** Dedicated keys belong in the Unraid container settings on the server. `.gitignore` ignores `login.ini` and `/settings/`. Samples keep placeholders.

**Rationale:** A key committed once remains in git history after deletion. `EUGEN_DEDICATED_KEY` is masked in the template.

## 2026-10-09 — One container per server

**Decision:** Each server is its own container, with its own name, game port, and settings folder. Additional servers may reuse the same login and key.

**Rationale:** Eugen allows a maximum of five servers for one login and key pair. Unraid reinstall replaces the existing container, so a second server is a new container.

## 2026-10-09 — Rebuild when Eugen publishes

**Decision:** `.github/workflows/rebuild-image.yml` publishes `ghcr.io/suchamoneypit/warno-unraid:latest` when the Eugen manifest digest changes, or when the wrapper build inputs change on `main`.

**Rationale:** Players on a new WARNO patch need a rebuilt dedicated server. A normal game patch should not require an edit to this repo.

## 2026-10-09 — Jungle Law preset, RCON unset

**Decision:** The published defaults are 2v2 Conquest for workshop item `3811913066`, with Map `RDPort_JungleLaw_2v2_CONQ`. A base-game scenario ID is valid when Workshop Mod List is cleared. RCON is not on the form.

**Rationale:** The first template commit (`6ee0739`) left RCON out. The Map default was empty until the scenario IDs from the Red Dragon mod files were recorded.

## 2026-10-09 — Agent guidance and checks

**Decision:** Always-on project rules live in `.cursor/rules/`. Specialist reviewers live in `.cursor/agents/`. Durable notes live in `docs/`. `scripts/check_repo.sh` checks XML well-formedness and local repository invariants.

**Rationale:** Template review, upstream research, and independent verification are different jobs. A parsed XML file still needs an Unraid install test before it can be treated as working.

## 2026-10-09 — Diff-scoped documentation check

**Decision:** `.cursor/agents/docs-consistency.md` is part of the generic set. It runs after a functional change that alters a user-facing name, default, description, port, path, image, or command. It compares only that change with the paired template, README, and install-doc lines. The parent applies the sentences it names. It does not review untouched docs, prose, or template structure, and it states no WARNO facts.

**Rationale:** A template field description can change while the README sentence for that field stays old. Checking the whole doc set on every edit costs more than the mismatches it finds.

## 2026-10-09 — Generic and WARNO-specific guidance kept apart

**Decision:** `.cursor/rules/agent-workflow.mdc`, `.cursor/rules/unraid-template.mdc`, `.cursor/agents/unraid-template-reviewer.md`, `.cursor/agents/verifier.md`, the five commands in `.cursor/commands/`, and `docs/UNRAID-TEMPLATE-GUIDE.md` contain no WARNO facts beyond a labeled project-specifics paragraph. WARNO facts live in `.cursor/rules/warno-project.mdc`, `.cursor/agents/warno-researcher.md`, `README.md`, `docs/INSTALL-UNRAID.md`, and the other `docs/` files. Subagents are launched by the main agent per the delegation table in `agent-workflow.mdc` or by the user with `/<name>`; nothing runs continuously.

**Rationale:** The generic half should move into a template repository for other game servers without editing. Rules reference docs by path instead of restating them, so the always-on context stays short.

## 2026-10-09 — Install route for Unraid 7

**Decision:** The install docs tell users to copy the template XML to `/boot/config/plugins/dockerMan/templates-user/` and pick it from **Add Container → Template → User templates**, with the Community Applications `private/` folder as the alternative. The raw GitHub URL is only the download source.

**Rationale:** The Community Applications author states that Unraid 6.10 removed the Template Repositories field, so the earlier "paste the template URL" instruction cannot be followed on Unraid 7. Neither route has been executed for this repository yet; the first real install should confirm it.
