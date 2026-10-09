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

**Decision:** `.github/workflows/rebuild-image.yml` publishes `ghcr.io/suchamoneypit/warhost:latest` when the Eugen manifest digest changes, or when the wrapper build inputs change on `main`. The same build also tags `ghcr.io/suchamoneypit/warno-unraid:latest`.

**Rationale:** Players on a new WARNO patch need a rebuilt dedicated server. A normal game patch should not require an edit to this repo.

## 2026-10-09 — Jungle Law preset, RCON unset

**Decision:** The published defaults are 2v2 Conquest for workshop item `3811913066`, with Map `RDPort_JungleLaw_2v2_CONQ`. A base-game scenario ID is valid when Workshop Mod List is cleared. RCON is not on the form.

**Rationale:** The first template commit (`6ee0739`) left RCON out. The Map default was empty until the scenario IDs from the Red Dragon mod files were recorded.

## 2026-10-09 — Handoff length

**Decision:** `/handoff` prints under 400 words. Words past a short status go to leftover intent, a do-not-redo list with a command, URL, or `file:line`, and git state (branch, commit, pushed or not). The paste points at `docs/` instead of restating them.

**Rationale:** A 250-word cap fit a long template session. A multi-thousand-word paste would reload that session into the next chat. The extra room is for intent and checks that the docs do not store.

## 2026-10-09 — Agent guidance and checks

**Decision:** Always-on project rules live in `.cursor/rules/`. Specialist reviewers live in `.cursor/agents/`. Durable notes live in `docs/`. `scripts/check_repo.sh` checks XML well-formedness and local repository invariants.

**Rationale:** Template review, upstream research, and independent verification are different jobs. A parsed XML file still needs an Unraid install test before it can be treated as working.

## 2026-10-09 — Diff-scoped documentation check

**Decision:** `.cursor/agents/docs-consistency.md` is part of the generic set. It runs after a functional change that alters a user-facing name, default, description, port, path, image, or command. It compares only that change with the paired template, README, and install-doc lines. The parent applies the sentences it names. It does not review untouched docs, prose, or template structure, and it states no WARNO facts.

**Rationale:** A template field description can change while the README sentence for that field stays old. Checking the whole doc set on every edit costs more than the mismatches it finds.

## 2026-10-09 — Generic and WARNO-specific guidance kept apart

**Decision:** `.cursor/rules/agent-workflow.mdc`, `.cursor/rules/unraid-template.mdc`, `.cursor/agents/unraid-template-reviewer.md`, `.cursor/agents/verifier.md`, the commands in `.cursor/commands/`, and `docs/UNRAID-TEMPLATE-GUIDE.md` contain no WARNO facts beyond a labeled project-specifics paragraph. WARNO facts live in `.cursor/rules/warno-project.mdc`, `.cursor/agents/warno-researcher.md`, `README.md`, `docs/INSTALL-UNRAID.md`, and the other `docs/` files. Subagents are launched by the main agent per the delegation table in `agent-workflow.mdc` or by the user with `/<name>`; nothing runs continuously.

**Rationale:** The generic half should move into a template repository for other game servers without editing. Rules reference docs by path instead of restating them, so the always-on context stays short.

## 2026-10-09 — Install route for Unraid 7

**Decision:** The install docs tell users to copy the template XML to `/boot/config/plugins/dockerMan/templates-user/my-<Name>.xml` and pick it from **Add Container → Template → User templates**, with the Community Applications `private/` folder as the alternative. The raw GitHub URL is only the download source. The flash filename uses `<Name>` as written, with a `my-` prefix.

**Rationale:** The Community Applications author states that Unraid 6.10 removed the Template Repositories field, so the earlier "paste the template URL" instruction cannot be followed on Unraid 7. Unraid's Template dropdown labels the file from its name with `my-` removed, and Unraid's own save path is `my-<Name>.xml` with that case kept. A download saved as `warno-dedicated-server.xml` was tried, and the dropdown showed that lowercase filename. `my-WARNO-Dedicated-Server.xml` has not been confirmed on a server yet. The private-folder route has not been executed.

## 2026-10-09 — Red Dragon ModList version

**Decision:** The preset Workshop Mod List is `3811913066/15`. The wrapper warns when that item is listed as `3811913066/0` and still starts the server. It does not query Steam for a newer `Version`.

**Rationale:** Eugen's Docker Hub page says the `ModList` version is usually `0`. This mod's `Config.ini`, read 2026-10-09, says `Version = 15` and tells the author to increment it when an update is incompatible. The operator's start with `3811913066/0` registered with matchmaking and produced no server line about the rejected join. The operator reported that `3811913066/15` allowed a client to join. The container has no copy of `Config.ini`, so a later increment has to be copied into the form by hand.

## 2026-10-09 — Which form fields stay visible

**Decision:** Max Players, Minimum Players, Team Size, and Combat Rule use `Display="always"`. Map, Workshop Mod List, and Workshop Mod Tags use `Display="advanced"`, after Write Config From Form, with Map and Workshop Mod List last. The Overview tells the operator to open Show more settings for the map and the mods.

**Rationale:** Those four player fields change with the map, and the preset is easy to miss if they sit behind Show more settings. Unraid prints each description under the input (`CreateDocker.php` `templateDisplayConfig`, read 2026-10-09), so the scenario-ID and workshop catalogs would make the default page very long. The Jungle Law preset is already filled in, so a first install can leave Show more settings closed. Map stays required; it is hidden because it is prefilled, not because it is optional.

## 2026-10-09 — Template icon

**Decision:** `icon.png` is the Community Applications / Unraid Docker icon. The template and `ca_profile.xml` `<Icon>` tags point at the raw GitHub URL of `icon.png` on `main`. The asset is a generated NATO-vs-Pact themed illustration chosen for this repository (not an Eugen press-kit file).

**Rationale:** Unraid and CA load the icon from that raw URL. Eugen's [Terms of Use](https://eugensystems.com/terms-of-use/) do not grant a trademark license; no official free logo kit was found. The chosen art is still fan/generated branding, not a Steam capsule or Eugen-distributed mark.

## 2026-10-09 — Day-to-day commits stay on dev

**Decision:** Commits land on `dev` and are pushed to `origin/dev` when the maintainer asks to commit. `main` changes only when the maintainer explicitly asks to publish the accumulated work. Community Apps reads the template, icon, and `ca_profile.xml` from `main`. `.github/workflows/rebuild-image.yml` rebuilds `ghcr.io/suchamoneypit/warhost:latest` and `ghcr.io/suchamoneypit/warno-unraid:latest` from `main` only.

**Rationale:** `main` is the snapshot strangers install. Template and doc commits there update the Apps listing on the Community Apps feed. `Dockerfile`, `entrypoint-unraid.sh`, and the rebuild workflow on `main` publish an image Unraid offers as a container update. Rapid work stays on `dev`, which neither feed reads.

## 2026-10-09 — Brand the project WARHOST

**Decision:** The product name is WARHOST. The Unraid `<Name>` is `WARHOST`, which is the Docker container name and the user-template label `my-WARHOST.xml`. The template file is `templates/warhost.xml`. The image the template installs is `ghcr.io/suchamoneypit/warhost:latest`. WARNO stays in the overview, `<ExtraSearchTerms>` (`WARNO WARNO server dedicated server game server mods modded`), the README title, and descriptive text. The host settings folder stays `/mnt/user/appdata/warno/settings`. Ports, map, mod list, and the other form defaults stay as they were. The rebuild also pushes `ghcr.io/suchamoneypit/warno-unraid:latest` so a container still pointed at that name keeps receiving game updates.

**Rationale:** `<Name>` is one field. Docker container names, and `scripts/print_template_fetch.sh`, allow letters, digits, dots, underscores, and hyphens. `WARHOST - WARNO Dedicated Server` cannot be that field. Community Apps searches `<ExtraSearchTerms>` as well as the name and overview, so WARNO remains a search term without renaming saved appdata. The GitHub repository is `WARHOST`. URLs in the template point at `suchamoneypit/WARHOST`. GitHub redirects the old repository URL. The template path change does not: `templates/warhost.xml` replaces `templates/warno-dedicated-server.xml` on `main`.
