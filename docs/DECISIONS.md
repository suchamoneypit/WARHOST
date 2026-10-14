# Decisions

Durable choices for this repository. Dates are the commit date or the day the decision was recorded. Read the index, then `rg` the title for the full entry. Superseded entries are in `docs/DECISIONS-ARCHIVE.md`.

## Index

- 2026-10-09 Wrap Eugen's image: the wrapper writes settings and execs `/server/entrypoint2.sh`; Eugen's launch arguments are not copied.
- 2026-10-09 Host networking: no published port; forward the game port (default `10400`) as TCP and UDP.
- 2026-10-09 Keys stay out of git: keys live in Unraid's container settings; `login.ini` and `/settings/` are gitignored; samples use placeholders.
- 2026-10-09 One container per server: each server is its own container with its own name, game port, and settings folder.
- 2026-10-09 Rebuild when Eugen publishes: the image rebuilds when Eugen's digest or the wrapper build inputs change.
- 2026-10-09 Install route for Unraid 7: copy the XML to `templates-user/my-<Name>.xml` on the flash; Unraid 6.10+ has no template-URL field.
- 2026-10-09 Template icon: `icon.png` on `main` is generated WARHOST art, not an Eugen asset.
- 2026-10-09 Day-to-day commits stay on dev: commits go to `dev`; `main` changes only on an explicit publish.
- 2026-10-09 Brand the project WARHOST: `<Name>` and the container are `WARHOST`; WARNO stays in search terms and prose.
- 2026-10-09 Keep scenario and mod catalogs in the README: catalogs live in the README; field descriptions stay under 240 characters with no `br`.
- 2026-10-09 Publish only the warhost image: only `ghcr.io/suchamoneypit/warhost` is published, not `warno-unraid`.
- 2026-10-09 Show the dedicated key in clear text: `EUGEN_DEDICATED_KEY` is `Mask="false"`; the log names only its last 4 characters.
- 2026-10-09 Keep the Eugen login in clear text on the form: `EUGEN_LOGIN` is `Mask="false"` too; credential review runs only on request or on a credential change.
- 2026-10-09 Several servers on one host: next container uses Game Port plus 1, its own folder and name; the wrapper locks the folder and refuses a taken port.
- 2026-10-09 Stage settings in a private directory: files are written in a mode-`700` `.warhost-stage.*` directory and renamed; symlinks are not followed.
- 2026-10-09 Settings folder path includes the game port: the host folder is `/mnt/user/appdata/warno/<port>/settings`.
- 2026-10-09 MIT covers the repository, not the container image: MIT `LICENSE` covers repository files; the image has no license label.
- 2026-10-09 Number each publish to main: each `main` push is tagged `vX.YY` and released; a higher `VERSION` sets the number.
- 2026-10-10 Slop review is a command in a new chat: `/slop-review` is a report-only review of what ships, run in a fresh chat.
- 2026-10-10 Empty mod list only fits a base-game map: an empty `ModList` with a non-base-game map warns and still starts.
- 2026-10-10 Workshop Version read at container start: a bare Workshop id becomes `id/Version` on each start; DepotDownloader reads only `Config.ini`.
- 2026-10-10 A stale VERSION does not stop the release: a `VERSION` below the latest tag is ignored and the tag increments.
- 2026-10-10 Branch templates keep separate flash names: `--branch` saves `my-<Name>-<branch>.xml`; `--clean` removes only those containers, files, and folders.
- 2026-10-11 No session handoff paste: no `/handoff`; continuity is the always-on rules, `docs/`, and git.
- 2026-10-11 The form field is WebUI, and a save does not add a workshop mod: the field and log lines say WebUI; the save rule was later replaced.
- 2026-10-11 WebUI is on by default and sits on the main form: `WEB_UI` defaults to `true` and follows Public WAN IP on the main form.
- 2026-10-11 Placeholder server name: the seed server name is `WARHOST - default server name`.
- 2026-10-11 WebUI owns the lobby: lobby fields left the Docker form; the WebUI edits `variables.ini`, seeded once when missing.
- 2026-10-11 The dev template installs a dev image: `dev` publishes `:dev` and its template points there; a publish switches to `:latest`.
- 2026-10-11 WebUI credits the workshop author on the checklist: checklist labels add `by` and the Workshop creator from the catalog.
- 2026-10-11 A catalog map keeps its combat rule: only the scenario's own combat rule is offered and saved.
- 2026-10-11 Save and restart re-execs the wrapper: `SIGUSR1` makes the PID-1 wrapper re-exec itself; no Docker socket.
- 2026-10-11 Player limits stay editable: choosing a map fills the player counts; they stay editable within Eugen's limits.
- 2026-10-11 Map packs and other workshop mods are separate checklists: map packs on the left, full conversions and other mods on the right, one `ModList`.
- 2026-10-12 Map pictures stay out of the published image: previews come from a local install into gitignored `webui/previews/`.
- 2026-10-12 Release notes say what a host would notice: written summaries in `scripts/release_notes.py` for `v0.90` through `v1.13`. A tag with no summary does not publish.
- 2026-10-12 PvP and PvE setup: PvE writes `CoopVsAI` and AI counts; `params_for_ai.json` is seeded only when missing.
- 2026-10-12 The map checklist is Workshop Maps: the left checklist heading is Workshop Maps.
- 2026-10-13 Community Applications is the main install route: the README and install guide lead with Apps, search WARHOST, Install; the flash-drive copy stays for `dev`.
- 2026-10-13 Shared agent files for Cursor and Claude Code: `CLAUDE.md`, `.claude/agents/`, and `.claude/skills/` serve both tools; one `reviewer`; `claude -p` via `scripts/ask_claude.sh`.
- 2026-10-13 Claude handoff effort is set per task: `effort` is `low` through `max`; routine calls use `medium`, and `/slop-review` uses `high`.
- 2026-10-13 The image workflow does not set package visibility: set `warhost` to Public in the package settings; the rebuild only publishes the image.

## 2026-10-09 — Wrap Eugen's image

**Decision:** `entrypoint-unraid.sh` writes settings and execs `/server/entrypoint2.sh`. This repo does not copy Eugen's server launch arguments.

**Rationale:** Game updates should come from `eugensystems/warno`. The wrapper only supplies the Unraid form. Recorded in commit `b8466df`.

## 2026-10-09 — Host networking

**Decision:** The template uses `<Network>host</Network>` and does not publish a Docker port. Operators forward `EXPOSEDPORT` as TCP and UDP. The default port is `10400`.

**Rationale:** Eugen recommends host networking and requires both protocols. Unraid host networking does not show a port mapping. `10400` is this template's default, not a port named by Eugen.

## 2026-10-09 — Keys stay out of git

**Decision:** Dedicated keys belong in the Unraid container settings on the server. `.gitignore` ignores `login.ini` and `/settings/`. Samples keep placeholders.

**Rationale:** A key committed once remains in git history after deletion. The Unraid form shows the key in clear text. That display stays on the server, not in this repository.

## 2026-10-09 — One container per server

**Decision:** Each server is its own container, with its own name, game port, and settings folder. Additional servers may reuse the same login and key.

**Rationale:** Eugen allows a maximum of five servers for one login and key pair. Unraid reinstall replaces the existing container, so a second server is a new container.

## 2026-10-09 — Rebuild when Eugen publishes

**Decision:** `.github/workflows/rebuild-image.yml` publishes `ghcr.io/suchamoneypit/warhost:latest` when the Eugen manifest digest changes, or when the wrapper build inputs change on `main`.

**Rationale:** Players on a new WARNO patch need a rebuilt dedicated server. A normal game patch should not require an edit to this repo.

## 2026-10-09 — Install route for Unraid 7

**Decision:** The install docs tell users to copy the template XML to `/boot/config/plugins/dockerMan/templates-user/my-<Name>.xml` and pick it from **Add Container → Template → User templates**, with the Community Applications `private/` folder as the alternative. The raw GitHub URL is only the download source. The flash filename uses `<Name>` as written, with a `my-` prefix.

**Rationale:** The Community Applications author states that Unraid 6.10 removed the Template Repositories field, so the earlier "paste the template URL" instruction cannot be followed on Unraid 7. Unraid's Template dropdown labels the file from its name with `my-` removed, and Unraid's own save path is `my-<Name>.xml` with that case kept. A download saved as `warno-dedicated-server.xml` was tried, and the dropdown showed that lowercase filename. `my-WARNO-Dedicated-Server.xml` has not been confirmed on a server yet. The private-folder route has not been executed.

## 2026-10-09 — Template icon

**Decision:** `icon.png` is the Community Applications / Unraid Docker icon. The template and `ca_profile.xml` `<Icon>` tags point at the raw GitHub URL of `icon.png` on `main`. The asset is a generated NATO-vs-Pact illustration with a WARHOST wordmark and a server-rack motif, chosen for this repository (not an Eugen press-kit file).

**Rationale:** Unraid and CA load the icon from that raw URL. Eugen's [Terms of Use](https://eugensystems.com/terms-of-use/) do not grant a trademark license; no official free logo kit was found. The chosen art is still fan/generated branding, not a Steam capsule or Eugen-distributed mark.

## 2026-10-09 — Day-to-day commits stay on dev

**Decision:** Commits land on `dev` and are pushed to `origin/dev` when the maintainer asks to commit. `main` changes only when the maintainer explicitly asks to publish the accumulated work. Community Apps reads the template, icon, and `ca_profile.xml` from `main`. `.github/workflows/rebuild-image.yml` rebuilds `ghcr.io/suchamoneypit/warhost:latest` from `main` only.

**Rationale:** `main` is the snapshot strangers install. Template and doc commits there update the Apps listing on the Community Apps feed. `Dockerfile`, `entrypoint-unraid.sh`, and the rebuild workflow on `main` publish an image Unraid offers as a container update. Rapid work stays on `dev`, which neither feed reads.

## 2026-10-09 — Brand the project WARHOST

**Decision:** The product name is WARHOST. The Unraid `<Name>` is `WARHOST`, which is the Docker container name and the user-template label `my-WARHOST.xml`. The template file is `templates/warhost.xml`. The image the template installs is `ghcr.io/suchamoneypit/warhost:latest`. WARNO stays in the overview, `<ExtraSearchTerms>` (`WARNO WARNO server dedicated server game server mods modded`), the README title, and descriptive text. The host settings folder stays `/mnt/user/appdata/warno/settings`. Ports, map, mod list, and the other form defaults stay as they were.

**Rationale:** `<Name>` is one field. Docker container names, and `scripts/print_template_fetch.sh`, allow letters, digits, dots, underscores, and hyphens. `WARHOST - WARNO Dedicated Server` cannot be that field. Community Apps searches `<ExtraSearchTerms>` as well as the name and overview, so WARNO remains a search term without renaming saved appdata. The GitHub repository is `WARHOST`. URLs in the template point at `suchamoneypit/WARHOST`. GitHub redirects the old repository URL. The template path change does not: `templates/warhost.xml` replaces `templates/warno-dedicated-server.xml` on `main`.

## 2026-10-09 — Keep scenario and mod catalogs in the README

**Decision:** Base-game scenario IDs and the named workshop mods live in `README.md`. Unraid field descriptions are one or two sentences and point at that README. `scripts/check_repo.sh` fails a Config description longer than 240 characters or one that contains a `br` tag.

**Rationale:** Unraid prints each description under its field. The Map and Workshop Mod List descriptions rendered as walls of IDs on 2026-10-09, including after `<br>` broke them into sections. A README table can be scanned. The form cannot.

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

## 2026-10-09 — Settings folder path includes the game port

**Decision:** The default host settings folder is `/mnt/user/appdata/warno/10400/settings`, the same number as Game Port `10400`. Each added container uses that path with its own Game Port, so port `10401` uses `/mnt/user/appdata/warno/10401/settings`. The Settings Folder description tells the next container to use this path with the port number plus 1. A shared-folder stop names this Game Port's folder, and the folder for the port plus 1 when that path is the one in use. A taken-port stop names the settings folder for that new port, for example `/mnt/user/appdata/warno/10401/settings`. The startup line names that same next folder. This supersedes the host-folder sentence in "Brand the project WARHOST." The container path stays `/server/settings`. The appdata directory name stays `warno`.

**Rationale:** A shared `/mnt/user/appdata/warno/settings` made a second container look like a copy of the first. On 2026-10-09 that shared folder stopped the second container, and both servers showed online with `/mnt/user/appdata/warno/10400/settings` and `/mnt/user/appdata/warno/10401/settings`. The plus-1 step is then the same one already used for Game Port.

## 2026-10-09 — MIT covers the repository, not the container image

**Decision:** `LICENSE` at the repository root is the standard MIT license, copyright 2026 suchamoneypit. It covers the templates, metadata, documentation, and `entrypoint-unraid.sh`. The template `<License>` tag is the raw URL of that file on `main`. `<ReadMe>` is the raw URL of `README.md` on `main`. The Dockerfile leaves `org.opencontainers.image.licenses` unset.

**Rationale:** Community Apps [submission help](https://ca.unraid.net/submit/help), fetched 2026-10-09, requires an OSI-approved `LICENSE` at the repository root before a submission can be finalized. The Before you begin step says that license is for repository contents (templates, metadata, and docs) and that container image licenses are separate. GitHub detects a license from a standard `LICENSE` file ([licensing a repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)). The GitHub API reported this repository as `MIT` on 2026-10-09. The Docker Hub API for `eugensystems/warno`, fetched the same day, states no license. An image license label of MIT would present that base image under this repository's license. `<ReadMe>` is the field the [starter template](https://github.com/unraid/unraid-community-apps-starter/blob/main/templates/example-app.xml) gives moderators for the long description. The [repository XML](https://ca.unraid.net/submit/help/repository-xml) page says moderators review from `<Name>` and `<Overview>`.

## 2026-10-09 — Number each publish to main

**Decision:** Every push to `main` gets a git tag and a GitHub Release from `.github/workflows/release.yml`. The first is `v0.90`. Later publishes add one to the two-digit minor part (`v0.91`, `v0.99` then `v1.00`, `v1.00` then `v1.01`) unless that publish includes a higher `VERSION` file. `1.0` in that file is `v1.00`. A file that still equals the latest tag increments. A file below the latest tag stops the release. The 2026-10-10 entry "A stale VERSION does not stop the release" replaces that stop. The annotated tag is created when that name is missing. A later run on a commit that already has a version tag keeps the lowest of those tags. The Unraid template stays on `ghcr.io/suchamoneypit/warhost:latest`. Daily and manual image rebuilds do not create a version.

**Rationale:** Publishes are occasional snapshots of `dev`. The number is how those snapshots are told apart. `:latest` still moves when Eugen's image digest changes between publishes, so a frozen image tag would not be the container Unraid is running.

## 2026-10-10 — Slop review is a command in a new chat

**Decision:** `.cursor/commands/slop-review.md` reviews what the repository ships the way a Community Applications moderator, a first-time installer, a security-minded homelabber, a WARNO host, and a technical editor would read it. It runs in the main chat of a new Agent session, on the model the maintainer picks. Until its report is written, it launches none of this repository's subagents and does not open `.cursor/plans/` or past chats. It reports and stops, and later applies only the finding IDs the maintainer names. It is not part of `/review-and-verify`. The body is generic; the WARHOST facts are in its Project specifics section.

**Rationale:** The project discloses AI use, so the question is whether the shipped text reads as reviewed work, not whether an AI wrote it. A subagent returns one message to the parent, and this repository keeps those messages short. This report is long by design, and the apply step needs its findings in the same chat. A new chat starts without the sessions that wrote the text, and this repository's subagents carry the same authoring assumptions. The template, README, install guide, wrapper, and icon get line-by-line scrutiny. Scripts, tests, workflows, and `.cursor/` are checked only for breakage, leaks, and contradictions.

## 2026-10-10 — Empty mod list only fits a base-game map

**Decision:** When Workshop Mod List is empty, the wrapper warns if Map is not one of the 102 base-game scenario IDs in the README, and still starts. Workshop scenario IDs that start with `_` are included in that warning. When Workshop Mod Tags is set and Workshop Mod List is empty, the wrapper prints a note that the tags are written and do not select modded content, and still writes the tags.

**Rationale:** An empty Workshop Mod List is the base-game preset, and only those maps run for players who have no workshop mod. Matching the README table, rather than every ID that starts with `_`, includes West Fulda, Highway to Oslo, Ramstein, Arsenal, and Helbe. The warning does not stop the start, matching the earlier mod-list warnings. The tags note is a disclaimer: the README already says those tags are browser icons and do not download mods.

## 2026-10-10 — Workshop Version read at container start

**Decision:** Workshop Mod List accepts a bare Workshop id, and the template example is `3811913066`. On each start, before `warno-server` launches, the wrapper turns every bare id into `id/Version` and writes that pair. A typed `id/version` is a pin and is written as typed. `warhost-workshop-versions.txt` in the settings folder caches `id time_updated Version`, and Steam's `time_updated` decides whether to read `Config.ini` again. That read is DepotDownloader 3.4.0, signed in anonymously, with a file list of `Config.ini` only, into a new directory in the settings folder that is removed before the next id. When the update check or the fetch fails and a cached `Version` exists, the wrapper writes it and warns. With no cached `Version` and no `Config.ini`, the start stops. The image installs DepotDownloader pinned by version and SHA-256, and no steamcmd.

**Rationale:** A client joins only when the number after the slash equals `Version` in the mod's `Config.ini`. Red Dragon went from 15 to 27 between 2026-10-09 and 2026-10-10, and the operator's server with the old number refused players while `warno-server` logged nothing. Steam's public item details have `time_updated` and `file_size` and no `Version`, so `Config.ini` has to be read. The server stands alone, so a Workshop folder mounted from a gaming PC was rejected. `steamcmd +workshop_download_item` has no file filter and would fetch Red Dragon's 9,059,324,422 bytes to read one line. DepotDownloader's `-filelist` filters the manifest before chunks are queued, and the measured read was 416 bytes plus a 419,989-byte manifest. Every mod names the file `Config.ini`, so ids are read one at a time and each directory is removed before the next. `ModGenVersion` is `201602` in all nine mods in the local Steam library, with the comment "ModGen revision, do not modify"; it identifies the mod generator, and `Version` is the number the client compares. One check per start keeps players in a running match, and a restart picks up a new `Version`. Anonymous access to app `1611600` Workshop manifests worked on 2026-10-10, so no Steam account is stored. A guessed number registers and then refuses every join without a log line, so a start with no `Version` stops and says why. DepotDownloader adds a 79 MB binary to the image; its GPL-2.0 license and source tag are in `README.md`.

## 2026-10-10 — A stale VERSION does not stop the release

**Decision:** A `VERSION` file below the latest git tag is ignored. The release workflow increments the latest tag, the same as when the file is absent or equal to that tag. A file higher than the latest tag is still the tag for that publish. The workflow still does not push a commit, and it still does not create a tag that already exists.

**Rationale:** The workflow reads `VERSION` and does not write it back. After a publish where the file matches the latest tag, the next tag is one minor higher and the file is unchanged. The following push to `main` then finds the file below the latest tag. On 2026-10-10 that stopped [Actions run 38097617043](https://github.com/suchamoneypit/WARHOST/actions/runs/38097617043): `VERSION` was `1.02` and the latest tag was `v1.03`, so `scripts/next_version.py` exited 1. Several agents publish without naming a new number, so the file stays behind whenever one of those pushes increments the tag. A lower file cannot rewind the number either way. Ignoring it keeps the next minor and lets that push finish.

## 2026-10-10 — Branch templates keep separate flash names

**Decision:** `scripts/print_template_fetch.sh --branch` rewrites the ref in `<TemplateURL>`. The ref already in that URL is saved as `my-<Name>.xml`. Any other branch is saved as `my-<Name>-<branch>.xml`. `/unraid-script` prints a separate paste for `main` and for `dev`, then a `--clean` paste for those two. `/first-unraid-install` is removed. `--clean` stops and removes containers named `<Name>` and `<Name>-dev`, drops an autostart line when its first field is one of those container names, removes `<Repository>` only when no container is still using that image, and deletes the two user-template files and the two private-template files. It removes `/mnt/user/appdata/warno/<port>/settings` for those containers: the template Settings Folder path, any path mounted at `/server/settings`, and any path saved in those template files. A folder still mounted by another container is left. It does not remove any other appdata path, and it does not remove a container whose name is not one of those two.

**Rationale:** One combined download installed every branch while a single branch was being tested. Separate flash names keep the dropdown entries distinct, and separate pastes keep an unused branch off the server. Apply still writes `my-<Name>.xml` from the Name field, so the clean-slate step has to remove that container and that file as well as the suffixed file. Previous Apps reads `templates-user`, and Unraid autostart reads `/var/lib/docker/unraid-autostart`. Leaving the image in place when another container uses it avoids deleting a second server's image. The settings folder holds the Eugen login and key, so a clean slate removes that folder for the containers being cleared and leaves a folder another container still mounts. The first-install walkthrough was for a setup that has already been done. The lobby page is a setting on `dev`, so there is no third template branch.

## 2026-10-11 — No session handoff paste

**Decision:** `/handoff` is removed. A new chat starts with the task. Continuity is the always-on rules, `docs/`, and `git status`. An unfinished goal is written to `docs/ROADMAP.md` during the work. `@Chats` or fork-chat is for when the thread itself has to carry over.

**Rationale:** The command spent a closing turn on a paste that was then loaded into the next chat. Git state, recorded fetches, and checks already live in the repo, and a pasted check result from the previous session is stale. The 2026-10-09 length cap does not apply anymore.

## 2026-10-11 — The form field is WebUI, and a save does not add a workshop mod

**Decision:** The Show more field is named WebUI. `Target` stays `WEB_UI` and the default stays `false`. The Show more placement and that default were replaced later the same day. The name, log lines, and save rules in this entry stay. The docker log says `WebUI is off. Nothing is listening on port N.` and `WebUI is off. Port N is already in use.` With it on, `webui/launch.sh` prints `WebUI listening on port N.` The page heading is WARHOST WebUI. The map list shows base-game maps. Modded maps appear only when `ModList` already contains that pack's workshop id. A save keeps the existing `ModList` and `ModTagList`. A modded map whose pack id is absent is rejected. The page does not write the Unraid template. The 2026-10-11 entry "WebUI owns the lobby" replaces that save rule: a save writes the checked workshop ids.

**Rationale:** Unraid's Docker button is already called WebUI, and the old field name did not tell an operator that the button and the field are the same page. The page cannot edit the template on the Unraid flash. Writing a catalog `id/version` would pin a Version the wrapper does not refresh while WebUI is on, and it would drop a second workshop id joined with a hyphen. Workshop mod tags do not identify a pack.

## 2026-10-11 — WebUI is on by default and sits on the main form

**Decision:** The template `WEB_UI` `Default` and element text are `true`. The Config uses `Display="always"` and follows Public WAN IP (`EXPOSEDIP`), before the Show more settings block. Workshop Mod List, Write Config From Form, and Workshop Mod Tags stay `Display="advanced"`, in that order. The 2026-10-11 entry "WebUI owns the lobby" removes Workshop Mod List and Workshop Mod Tags from the form. An unset `WEB_UI` in the wrapper still means off (`${WEB_UI:-false}`). A container saved from the earlier template keeps `false` until that field is changed.

**Rationale:** A new container should serve the page, and the field should be visible without opening Show more settings, immediately after Public WAN IP. Unraid appends `Display="advanced"` fields to the Show more settings block (`CreateDocker.php` `templateDisplayConfig`, already recorded in `docs/ARCHITECTURE.md`). The wrapper's missing-value fallback stays off so a start that does not set the variable does not gain a listener.

## 2026-10-11 — Placeholder server name

**Decision:** The template default, the sample, and the wrapper fallback when Server Name is empty are `WARHOST - default server name`. Map stays `_2x2_Hesse_2vs2_CONQ`. The WebUI starting-resources menu includes `750` in numeric order. Income factor labels on that page use a decimal point (`x0.5`, `x0.75`, `x1.5`). The stored `IncomeRate` values stay `0` through `5`.

**Rationale:** `WARHOST - Hesse 2v2` reads as a configured live server when nobody has set a name. The placeholder is what a new container writes, and what the wrapper writes when Server Name is empty. A container saved from an earlier template keeps the old name until that field is edited. A new settings folder is seeded with `WARHOST - default server name`; change that name in the WebUI. There is no Reset from Unraid form. `750` is the `InitMoney` value the wrapper writes. The starting-resources menu lists `750` between `500` and `1000`. The income labels keep the same factors recorded from the lobby screens and print the fraction with a decimal point. The entry "WebUI owns the lobby" removes that form field and the reset button. The seed name stays `WARHOST - default server name`.

## 2026-10-11 — WebUI owns the lobby

**Decision:** The Docker template no longer has Server Name, Map, Max Players, Minimum Players, Team Size, Combat Rule, Workshop Mod List, or Workshop Mod Tags. It keeps the settings folder, Eugen login, dedicated key, public WAN IP, WebUI, Game Port, and Write Config From Form. With Write Config true, every start rewrites `login.ini` and `params_for_ai.json`. The 2026-10-12 entry replaces that every-start rewrite. A missing `variables.ini` is seeded once with `WARHOST - default server name`, map `_2x2_Hesse_2vs2_CONQ`, 4/2/2 slots, Conquest, and no mods. An existing file is kept. A bare Workshop id in its `ModList` is rewritten as `id/Version`; a pin stays a pin. Leftover lobby environment variables are ignored, and the log says `Lobby settings on the Docker template are ignored. Change the server in the WebUI.` The page checklist covers the six map packs plus Galactic Divide and A World in Flames. A save writes catalog ids as bare ids, keeps an unknown id that was already in the file, and derives `ModTagList` from the checked mods. A World in Flames contributes `Gameplay-Interface`, or `Gameplay-Interface-Maps-Scenarios` when a map pack is also checked. There is no Reset from Unraid form button. A save writes the posted Max players, Team size, and Minimum players.

**Rationale:** The page cannot write the Unraid template on the flash drive, so the form and the page cannot update each other. On 2026-10-11 a server name set on the Docker form was ignored after the first start, and the page showed the seed name. Putting workshop mods on the form while the map lives on the page would make the operator edit both. A save writes bare ids so the next start can read `Version` from Steam. A pin left in the file is left alone until that mod is saved again.

## 2026-10-11 — The dev template installs a dev image

**Decision:** Pushes to `dev` that change `Dockerfile`, `entrypoint-unraid.sh`, `webui/`, or `.github/workflows/rebuild-image.yml` publish `ghcr.io/suchamoneypit/warhost:dev`. `ghcr.io/suchamoneypit/warhost:latest` is still published from `main` only. The template `<Repository>` on `dev` is the `:dev` tag. Publishing to `main` sets that element back to `:latest` before the merge. `scripts/check_repo.sh` enforces the tag for the current branch.

**Rationale:** The dev template no longer sends `MAP`. Images from `main` before v1.10 stop when Map is unset, so that WebUI never starts. After **Rebuild WARHOST image** finishes for that publish, `ghcr.io/suchamoneypit/warhost:latest` starts with Map unset and serves the page. A pull of the dev template was still `ghcr.io/suchamoneypit/warhost:latest`, so the container kept the old entrypoint. The `:dev` tag is the image whose entrypoint seeds `_2x2_Hesse_2vs2_CONQ` when `variables.ini` is missing and keeps an existing file.

## 2026-10-11 — WebUI credits the workshop author on the checklist

**Decision:** Each workshop checkbox is the catalog name and, when `author` is non-empty, `by` plus that name in the same label. The string is the Steam Workshop "Created by" display name stored in `webui/scenarios.json` by `webui/make_catalog.py`. A missing or blank author, including an id that is not in the catalog, shows the name only. The credit is not written to `variables.ini` and is not read from `Config.ini`.

**Rationale:** The checklist names the mod and not the person who published it. `Config.ini` in the local Steam library has no author key (checked 2026-10-11). The Workshop page shows the creator. Those eight names were read the same day and stored in the catalog so the page does not call Steam. A later rename on Steam stays on the old credit until the catalog is updated. Red Dragon's description credits Eugen Systems for the original assets; the Workshop creator field is Zim, and that is the name on the checkbox.

## 2026-10-11 — A catalog map keeps its combat rule

**Decision:** The Combat rules menu offers only the rule stored on the selected scenario. A save whose combat rule differs is rejected with `That map is Conquest only.` or `That map is Destruction only.` A map that is not in the catalog and already in `variables.ini` still accepts Destruction `1` or Conquest `2`.

**Rationale:** Each scenario ID is one mode. Paddy Field is Conquest (`rule` 2). The menu listed both modes after the row was selected, and a save wrote the posted value. The list filter still searches by rule and does not assign one.

## 2026-10-11 — Save and restart re-execs the wrapper

**Decision:** Save and restart compares the form with the `variables.ini` already written for this server. If they differ, the page asks `Save these settings and restart the container? The current match will stop.` and, after confirmation, writes the file and signals the wrapper. If they do not differ, the page asks `No settings have changed, are you sure you want to restart the container?` and signals the wrapper only after confirmation. The wrapper stays PID 1, runs `/server/entrypoint2.sh` in its own session, and on `SIGUSR1` stops that session and `exec`s `entrypoint-unraid.sh` again. The page process stays up. There is no Docker socket mount. If `.warhost-supervisor.pid` does not name the wrapper, a changed form is still saved and the page says `This page cannot restart the container. Restart it in Unraid to load the save.`

**Rationale:** `variables.ini` is read when the dedicated server starts, and a bare Workshop id is resolved on that same start. Exiting only the WebUI would leave the match on the old file. The Docker socket is not mounted, and host networking does not provide it. Killing PID 1 would stop the container and would not start it again: the template sets no restart policy. Keeping the wrapper as PID 1 re-runs the existing start, including the Workshop version read, without a new host capability. The page is not the parent of `warno-server`. A page crash still does not stop the match.

## 2026-10-11 — Player limits stay editable

**Decision:** The WebUI shows Max players (`NbMaxPlayer`), Team size (`MaxTeamSize`), and Minimum players (`NbMinPlayer`). Choosing a map fills them from that scenario: `players`, `team`, and a minimum of 2 when `players` is at least 2, otherwise the scenario's player count. The controls are not locked. A save writes the posted values when they are present, from 1 to 20 for max players and from 1 to that max for team size and minimum players. Omitting them on a catalog map still writes the scenario preset, which is what older saves did. The seed in `entrypoint-unraid.sh` stays `NbMaxPlayer` 4, `NbMinPlayer` 2, `MaxTeamSize` 2. Those fields stay off the Docker form. This replaces the earlier rule that a save set the usual player counts from the map alone.

**Rationale:** Hosts run a larger lobby on a smaller map, such as 8 and 4 on a 2v2 scenario, and a smaller lobby, such as max 2, team size 1, and minimum 2 for a 1v1 on that same map. Eugen's `variables.ini` page, already cited in `docs/ARCHITECTURE.md`, does not tie `NbMaxPlayer` or `MaxTeamSize` to the size token in the scenario ID. `NbMinPlayer` is the minimum key already written by the seed. Whether an 8-player lobby opens on a 2v2 scenario is still untested on a running server.

## 2026-10-11 — Map packs and other workshop mods are separate checklists

**Decision:** The WebUI workshop section has two checklists above the map list. The left one keeps the heading Workshop mods and lists catalog groups that have a `modList`. Those are the map packs. The right one is headed Full conversions and other mods and lists the catalog `mods` array, which `webui/make_catalog.py` fills from README workshop rows that are not those packs. An id already in `variables.ini` that is in neither list is a checkbox on the right, labeled Workshop id and that id. Checked ids from both lists are still one `mods` array. Their order stays the previous `ModList` order, and a newly checked id is appended. A save still writes catalog ids as bare ids.

**Rationale:** Map packs are the common case and stay in the existing list. Galactic Divide and A World in Flames are already stored in `mods` because they are not scenario groups. The page uses that split, so a later mod follows the catalog instead of a name list. An id the catalog does not know is not a map pack, so it stays on the right. Moving a checkbox between the lists does not change the ids written to `variables.ini`.

## 2026-10-12 — Map pictures stay out of the published image

**Decision:** `scripts/extract_map_previews.py` copies each battlefield's Overview and Preview pictures from a local WARNO install into `webui/previews/`. The WebUI shows Overview as Scenic view and Preview as Tactical zones when `index.json` names that map. The same pair is used for every scenario ID that starts with that map stem. `webui/previews/` is gitignored and listed in `.dockerignore`. The published image keeps the text labels.

**Rationale:** On 2026-10-12 the local install stored those pictures as WebP or PNG inside `Maps/*_Details.dat`, including `_2x2_Hesse_Details.dat` and Red Dragon's `RDPort_JungleLaw_Details.dat`. The `.tgv` files in `*_Assets.dat` are a second copy and are not used. A public wiki does not publish a current set. Putting the files in git or in `ghcr.io/suchamoneypit/warhost` would redistribute Eugen's art.

## 2026-10-12 — Release notes say what changed

**Decision:** Each GitHub Release body is what a host would notice in that version, then the compare link. `scripts/release_notes.py` holds that summary for `v0.90` through `v1.13`. A version with no change to the server, the Unraid form, or the WebUI says so in one line. A tag with no written summary fails the release job before the tag is pushed. `.github/workflows/release.yml` publishes that text. `python3 scripts/release_notes.py --apply` writes these summaries onto the releases already on GitHub.

**Rationale:** `gh release create --generate-notes` wrote only the compare link. On 2026-10-12 the twelve releases from `v0.90` through `v1.11` were that link, except a one-line note added by hand on `v1.02`. This repository publishes by pushing `main`, and those generated notes listed none of the commits. The earlier tags mix host changes with wording commits, so their pages use a written summary. On 2026-10-13 the `v1.12` and `v1.13` pages were the commit subjects, including a test file and agent setup. A later tag does not list commit subjects.

## 2026-10-12 — PvP and PvE setup

**Decision:** The WebUI setup control sits above Game parameters. Its labels are PvP and PvE setup. PvP uses the existing Max players, Team size, and Minimum players save. That save does not add `CoopVsAI` when the key is absent, and it does not write `params_for_ai.json`. PvE setup hides those three fields. It writes `CoopVsAI` `1` or `2`, sets `NbMinPlayer` to the human count, `NbMaxPlayer` to the human count plus the AI count, `MaxTeamSize` to the larger of those counts, and `DeltaMaxTeamSize` to the difference. It requires at least one deck on the AI side in `params_for_ai.json`. Switching back to PvP sets `CoopVsAI` to `0` and `DeltaMaxTeamSize` to `0`, and leaves the deck file. With Write Config true, a start rewrites `login.ini` and seeds `params_for_ai.json` only when that file is missing or a symlink. An existing regular file is kept. The Hesse seed does not gain `CoopVsAI`. `AutoFillAI` is not written.

**Rationale:** The PvP form already works, and mixing AI counts into those three fields would change it. Eugen's Docker Hub page, cited in `docs/ARCHITECTURE.md`, documents `CoopVsAI` and one `MaxTeamSize` for each team. A 2-human and 4-AI lobby therefore cannot cap the human side at 2. Spawning that extra AI is still untested. On 2026-10-12 the operator reported a `params_for_ai.json` failure on every container start. The wrapper was rewriting two empty deck lists on every start. The `warno-server` sentence was not copied. Keeping the file stops that rewrite. A PvE setup save is what replaces the empty lists.

## 2026-10-12 — The map checklist is Workshop Maps

**Decision:** The left WebUI checklist heading is Workshop Maps. It still lists the catalog map packs. The right checklist stays Full conversions and other mods.

**Rationale:** The left list is only map packs. Workshop mods named both lists. The 2026-10-11 entry "Map packs and other workshop mods are separate checklists" used the old heading.

## 2026-10-13 — Community Applications is the main install route

**Decision:** The README Install section and step 5 of `docs/INSTALL-UNRAID.md` start with the Apps tab: search for WARHOST, choose Install, fill in the form, Apply. That installs the `main` template. The flash-drive copy printed by `scripts/print_template_fetch.sh`, and its `--private` variant, stay as the route for the `dev` template and for a template change Community Applications has not picked up yet. `scripts/check_repo.sh` still requires those commands in both docs. This replaces the "until Community Applications lists it" framing in "Install route for Unraid 7".

**Rationale:** The maintainer reported on 2026-10-13 that Community Applications published the listing, after approval on 2026-10-09. The Apps tab is the route a first-time installer expects. The `dev` template points at `ghcr.io/suchamoneypit/warhost:dev` and is not in the listing, so testing a branch still needs the flash-drive copy.

## 2026-10-13 — Shared agent files for Cursor and Claude Code

**Decision:** `CLAUDE.md` is the one always-on instruction file. Cursor loads it as a rule and Claude Code reads it natively, so `.cursor/rules/agent-workflow.mdc` and `.cursor/rules/warno-project.mdc` are removed. Subagents live in `.claude/agents/` and commands in `.claude/skills/`, which both tools load. `.cursor/commands/` keeps only the Cursor-only `/webui` and `/ask-claude`. `docs-consistency`, `unraid-template-reviewer`, and `verifier` are one `reviewer`, run once per batch before a commit. Cursor hands work to Claude through `scripts/ask_claude.sh`; how often is set in `.cursor/rules/cursor-to-claude.mdc`. Claude Code never commits: `.claude/settings.json` denies commit, push, merge, rebase, hard reset, and tag. Superseded entries moved to `docs/DECISIONS-ARCHIVE.md`, and dated observations moved from `docs/ARCHITECTURE.md` to `docs/EVIDENCE.md`. Older entries that name `.cursor/agents/` or `.cursor/commands/` files refer to the same files now under `.claude/`. `CLAUDE.md` holds both workflow and WARNO facts, which replaces the generic and WARNO-specific rule split.

**Rationale:** The maintainer uses a Cursor subscription and a Claude subscription. Cursor's [rules](https://cursor.com/docs/rules.md), [subagents](https://cursor.com/docs/subagents.md), and [skills](https://cursor.com/docs/skills.md) pages say it loads `CLAUDE.md`, `.claude/agents/`, and `.claude/skills/`, so one copy serves both tools and nothing loads twice. Three reviewers each reread the same diff in a fresh context; one reviewer with the same checklist reads it once. Agents read all of this file for each feature; the index above and `docs/PROJECT-MAP.md` replace that read. `claude -p` spends the Claude subscription on reviews and stuck bugs, and the wrapper keeps those calls read-only unless edit mode is chosen on a clean tree.

## 2026-10-13 — Claude handoff effort is set per task

**Decision:** Each task in `.cursor/rules/cursor-to-claude.mdc` has `effort`: `low`, `medium`, `high`, `xhigh`, or `max`. `scripts/ask_claude.sh` passes it as `claude --effort`. Routine Sonnet tasks use `medium`. `/slop-review` uses `high`. Omitting `--effort` leaves Claude Code's own default.

**Rationale:** The model name does not set how long Claude thinks. `claude --help` on this machine lists those five levels. The installed Claude Code model catalog marks Medium as recommended for Opus 5.5 and Sonnet 5.5, and says Opus Max can consume 3.5× or more usage than Medium. The handoff names the level so a call is not Max unless the settings say so.

## 2026-10-13 — The image workflow does not set package visibility

**Decision:** `rebuild-image.yml` publishes the image and leaves package visibility to the package settings. Set `warhost` to Public there. Unraid pulls anonymously.

**Rationale:** The old step ran `gh api --method PUT /user/packages/container/warhost/visibility` with `GITHUB_TOKEN`. The packages REST reference lists get, list, delete, and restore, and no visibility update ([REST API endpoints for packages](https://docs.github.com/en/rest/packages/packages), read 2026-10-13). A new container package stays private until that change is made in the package settings ([Working with the Container registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)). `continue-on-error: true` had been on the step since it was added, so [run 31](https://github.com/suchamoneypit/WARHOST/actions/runs/38433376974) and [run 32](https://github.com/suchamoneypit/WARHOST/actions/runs/38433786247) reported the step as success. Removing that flag in `6e589ec` made [run 33](https://github.com/suchamoneypit/WARHOST/actions/runs/38494130558) fail after Build and push. The public annotation is only exit code 1; the step log needs a signed-in session. Anonymous manifest reads of `:latest` and `:dev` returned HTTP 200 the same day.
