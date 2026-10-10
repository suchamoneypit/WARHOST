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

**Rationale:** A key committed once remains in git history after deletion. The Unraid form shows the key in clear text. That display stays on the server, not in this repository.

## 2026-10-09 — One container per server

**Decision:** Each server is its own container, with its own name, game port, and settings folder. Additional servers may reuse the same login and key.

**Rationale:** Eugen allows a maximum of five servers for one login and key pair. Unraid reinstall replaces the existing container, so a second server is a new container.

## 2026-10-09 — Rebuild when Eugen publishes

**Decision:** `.github/workflows/rebuild-image.yml` publishes `ghcr.io/suchamoneypit/warhost:latest` when the Eugen manifest digest changes, or when the wrapper build inputs change on `main`.

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

Replaced the same day by the next entry, after those catalogs moved to `README.md`.

## 2026-10-09 — Map on the main form

**Decision:** Map uses `Display="always"` and follows Server Name, before Max Players. Workshop Mod List, Write Config From Form, and Workshop Mod Tags use `Display="advanced"`, in that order.

**Rationale:** The scenario-ID and workshop catalogs are in `README.md`, so the Map line on the form is one sentence. Map is the lobby operators change with the server, so it stays on the main form under Server Name. Workshop Mod List, the write-config switch, and Workshop Mod Tags stay behind Show more settings.

## 2026-10-09 — Template icon

**Decision:** `icon.png` is the Community Applications / Unraid Docker icon. The template and `ca_profile.xml` `<Icon>` tags point at the raw GitHub URL of `icon.png` on `main`. The asset is a generated NATO-vs-Pact illustration with a WARHOST wordmark and a server-rack motif, chosen for this repository (not an Eugen press-kit file).

**Rationale:** Unraid and CA load the icon from that raw URL. Eugen's [Terms of Use](https://eugensystems.com/terms-of-use/) do not grant a trademark license; no official free logo kit was found. The chosen art is still fan/generated branding, not a Steam capsule or Eugen-distributed mark.

## 2026-10-09 — Day-to-day commits stay on dev

**Decision:** Commits land on `dev` and are pushed to `origin/dev` when the maintainer asks to commit. `main` changes only when the maintainer explicitly asks to publish the accumulated work. Community Apps reads the template, icon, and `ca_profile.xml` from `main`. `.github/workflows/rebuild-image.yml` rebuilds `ghcr.io/suchamoneypit/warhost:latest` from `main` only.

**Rationale:** `main` is the snapshot strangers install. Template and doc commits there update the Apps listing on the Community Apps feed. `Dockerfile`, `entrypoint-unraid.sh`, and the rebuild workflow on `main` publish an image Unraid offers as a container update. Rapid work stays on `dev`, which neither feed reads.

## 2026-10-09 — Brand the project WARHOST

**Decision:** The product name is WARHOST. The Unraid `<Name>` is `WARHOST`, which is the Docker container name and the user-template label `my-WARHOST.xml`. The template file is `templates/warhost.xml`. The image the template installs is `ghcr.io/suchamoneypit/warhost:latest`. WARNO stays in the overview, `<ExtraSearchTerms>` (`WARNO WARNO server dedicated server game server mods modded`), the README title, and descriptive text. The host settings folder stays `/mnt/user/appdata/warno/settings`. Ports, map, mod list, and the other form defaults stay as they were.

**Rationale:** `<Name>` is one field. Docker container names, and `scripts/print_template_fetch.sh`, allow letters, digits, dots, underscores, and hyphens. `WARHOST - WARNO Dedicated Server` cannot be that field. Community Apps searches `<ExtraSearchTerms>` as well as the name and overview, so WARNO remains a search term without renaming saved appdata. The GitHub repository is `WARHOST`. URLs in the template point at `suchamoneypit/WARHOST`. GitHub redirects the old repository URL. The template path change does not: `templates/warhost.xml` replaces `templates/warno-dedicated-server.xml` on `main`.

## 2026-10-09 — Show the last 4 characters of the dedicated key

**Decision:** The Eugen dedicated key stays `Mask="true"`. A second always-visible field, Key last 4 (`EUGEN_KEY_LAST4`), must equal the last 4 characters of that key when Write Config From Form is true, or that start stops. It is not written to `login.ini`. The startup line names those 4 characters and not the rest of the key.

**Rationale:** One login can run five servers, and an operator may have two keys across several containers. Unraid's masked field hides the whole value, so the form cannot reveal four characters inside that box. The companion field is what stays readable when the container is opened later.

## 2026-10-09 — Keep scenario and mod catalogs in the README

**Decision:** Base-game scenario IDs and the named workshop mods live in `README.md`. Unraid field descriptions are one or two sentences and point at that README. `scripts/check_repo.sh` fails a Config description longer than 240 characters or one that contains a `br` tag.

**Rationale:** Unraid prints each description under its field. The Map and Workshop Mod List descriptions rendered as walls of IDs on 2026-10-09, including after `<br>` broke them into sections. A README table can be scanned. The form cannot.

## 2026-10-09 — Do not claim a 2v2 map accepts eight players

**Decision:** Max Players says the lobby is not locked to the map and that 8 slots on a 2v2 map is untested. Team Size stays the per-side count. The README gives the usual lobby for each size once, and says the same untested sentence once. The wrapper still accepts any Max Players from 1 to 20.

**Rationale:** Eugen's Docker Hub text, fetched 2026-10-09, defines `NbMaxPlayer` as how many players can join (maximum 20) and `MaxTeamSize` as the maximum on one side. It never says those must match the size in the scenario ID. Whether `RDPort_JungleLaw_2v2_CONQ` with 8 and 4 opens a 4v4 lobby has not been run.

## 2026-10-09 — Publish only the warhost image

**Decision:** `.github/workflows/rebuild-image.yml` pushes `ghcr.io/suchamoneypit/warhost:latest` and does not tag `ghcr.io/suchamoneypit/warno-unraid`.

**Rationale:** The project is still pre-alpha and the only operator already uses WARHOST. The second package was an alias for a container still pointed at the previous image name.

## 2026-10-09 — Show the dedicated key in clear text

**Decision:** `EUGEN_DEDICATED_KEY` uses `Mask="false"`. There is no Key last 4 field. This supersedes "Show the last 4 characters of the dedicated key." The key still never enters git. The startup line still names only the last 4 characters.

**Rationale:** Unraid's `Mask="true"` hides every character of a password input. [CreateDocker.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/CreateDocker.php), read on 2026-10-09, has no control that reveals four characters inside that box. The edit page is how an operator tells servers apart. A companion field had to be typed by hand and could stop a start when it did not match.

## 2026-10-09 — Keep the Eugen login in clear text on the form

**Decision:** `EUGEN_LOGIN` uses `Mask="false"`, the same as `EUGEN_DEDICATED_KEY`. Clear text on those two Unraid form fields is accepted. The Docker edit page is an admin screen. The login and the key still never enter git, samples, issues, or chat. The startup line still names only the last 4 characters of the key. `.cursor/agents/credential-reviewer.md` and `.cursor/commands/credential-review.md` are WARNO-specific. The main agent launches that reviewer only for `/credential-review`, or when a change writes, logs, templates, or documents the Eugen login, dedicated key, or `login.ini`. It is not part of `/review-and-verify`.

**Rationale:** The edit page is where an admin enters the pair from Eugen's reply. Masking the login would hide it on the same screen that already shows the key. An always-on review would rerun that audit on unrelated edits. The checklist lives in the agent so a later review does not recommend masking the form. This adds those two files to the WARNO-specific set from "Generic and WARNO-specific guidance kept apart."

## 2026-10-09 — Several servers on one host

**Decision:** Each added container uses the previous Game Port plus 1, its own settings folder, and a different Server Name. The same Public WAN IP is reused. The same login and key run five servers; this wrapper does not count them. The wrapper locks `warhost.lock` in the settings folder for the life of the process and refuses a Game Port that is already listening on TCP or bound on UDP. A TCP socket in TIME_WAIT does not count. `WARHOST_PORT_TABLE` is a test seam, not a form field. Docker stores the image once. This repo does not add a volume for a game library.

**Rationale:** Eugen's Docker Hub page, fetched 2026-10-09, documents one exposed port, forwarded as TCP and UDP, and a maximum of five servers per login/apikey pair. Players join by Server Name. Sharing a settings folder lets the last start overwrite the others. The image has no Steam library, so a library volume would invite a multi-gig copy per server. A shared mount waits until a running server shows a large directory and its path.

## 2026-10-09 — Stage settings in a private directory

**Decision:** The wrapper writes `login.ini`, `variables.ini`, and `params_for_ai.json` in one mode-`700` directory under the settings folder. The name starts with `.warhost-stage.` and ends in a unique suffix. A symlink at `login.ini`, `variables.ini`, or `params_for_ai.json` is removed instead of followed. A directory at one of those names stops the start. `umask 077` is set first. `mktemp -d` creates the directory when that command exists; otherwise a `mkdir` retry does. The directory is removed on `EXIT`, `HUP`, `INT`, and `TERM`. After `warhost.lock` is held, leftover real directories with that prefix are removed. Symlinks with that prefix are left in place. `WRITE_CONFIG=false` still does not rewrite the three files, and it sets `login.ini` to mode `600`. A crash, `SIGKILL`, or power loss can leave a mode-`700` staging directory until the next locked start. That leftover is accepted. The form fields and the last-four startup line stay as they are.

**Rationale:** A fixed `.login.ini.new` path opened with `>` follows a symlink planted in the settings folder. Traps do not run after `SIGKILL` or a host crash. The next start that holds the settings lock deletes those leftovers. Clearing them without the lock could delete another container's in-progress directory when `flock` is missing.

## 2026-10-09 — Number each publish to main

**Decision:** Every push to `main` gets a git tag and a GitHub Release from `.github/workflows/release.yml`. The first is `v0.90`. Later publishes add one to the two-digit minor part (`v0.91`, `v0.99` then `v1.00`, `v1.00` then `v1.01`) unless that publish includes a higher `VERSION` file. `1.0` in that file is `v1.00`. A file that still equals the latest tag increments. A file below the latest tag stops the release. The annotated tag is created when that name is missing. A later run on a commit that already has a version tag keeps the lowest of those tags. The Unraid template stays on `ghcr.io/suchamoneypit/warhost:latest`. Daily and manual image rebuilds do not create a version.

**Rationale:** Publishes are occasional snapshots of `dev`. The number is how those snapshots are told apart. `:latest` still moves when Eugen's image digest changes between publishes, so a frozen image tag would not be the container Unraid is running.
