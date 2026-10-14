# Decisions archive

Entries from `docs/DECISIONS.md` that a later decision replaced, kept for the history. Each one names the entry that replaced it, or that entry names this one.

## 2026-10-09 — Form-written settings

**Decision:** `WRITE_CONFIG` defaults to true and rewrites `login.ini`, `variables.ini`, and `params_for_ai.json` on each start. Set it false only for hand-edited files. The 2026-10-11 entry "WebUI owns the lobby" replaces the `variables.ini` half: a missing file is seeded, and an existing file is kept except for a bare Workshop id. The 2026-10-12 entry replaces that every-start rewrite.

**Rationale:** The Unraid form is the supported way to configure a server. Hand edits would otherwise be mistaken for the source of truth. Recorded in commit `b8466df`.

## 2026-10-09 — Jungle Law preset, RCON unset

**Decision:** The published defaults are 2v2 Conquest for workshop item `3811913066`, with Map `RDPort_JungleLaw_2v2_CONQ`. A base-game scenario ID is valid when Workshop Mod List is cleared. RCON is not on the form. The 2026-10-10 entry "Base-game defaults, workshop fields start empty" replaces these defaults; RCON is still not on the form.

**Rationale:** The first template commit (`6ee0739`) left RCON out. The Map default was empty until the scenario IDs from the Red Dragon mod files were recorded.

## 2026-10-09 — Handoff length

**Decision:** `/handoff` prints under 400 words. Words past a short status go to leftover intent, a do-not-redo list with a command, URL, or `file:line`, and git state (branch, commit, pushed or not). The paste points at `docs/` instead of restating them. The 2026-10-11 entry removes the command.

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

## 2026-10-09 — Red Dragon ModList version

**Decision:** On 2026-10-09 the preset was `3811913066/15` and the wrapper warned only for `3811913066/0`; the 2026-10-10 entry replaces both.

**Rationale:** Eugen's Docker Hub page says the `ModList` version is usually `0`. This mod's `Config.ini`, read 2026-10-09, says `Version = 15` and tells the author to increment it when an update is incompatible. The operator's start with `3811913066/0` registered with matchmaking and produced no server line about the rejected join. The operator reported that `3811913066/15` allowed a client to join. The container has no copy of `Config.ini`, so a later increment has to be copied into the form by hand.

## 2026-10-09 — Which form fields stay visible

**Decision:** Max Players, Minimum Players, Team Size, and Combat Rule use `Display="always"`. Map, Workshop Mod List, and Workshop Mod Tags use `Display="advanced"`, after Write Config From Form, with Map and Workshop Mod List last. The Overview tells the operator to open Show more settings for the map and the mods.

**Rationale:** Those four player fields change with the map, and the preset is easy to miss if they sit behind Show more settings. Unraid prints each description under the input (`CreateDocker.php` `templateDisplayConfig`, read 2026-10-09), so the scenario-ID and workshop catalogs would make the default page very long. The Jungle Law preset is already filled in, so a first install can leave Show more settings closed. Map stays required; it is hidden because it is prefilled, not because it is optional.

Replaced the same day by the next entry, after those catalogs moved to `README.md`.

## 2026-10-09 — Map on the main form

**Decision:** Map uses `Display="always"` and follows Server Name, before Max Players. Workshop Mod List, Write Config From Form, and Workshop Mod Tags use `Display="advanced"`, in that order.

**Rationale:** The scenario-ID and workshop catalogs are in `README.md`, so the Map line on the form is one sentence. Map is the lobby operators change with the server, so it stays on the main form under Server Name. Workshop Mod List, the write-config switch, and Workshop Mod Tags stay behind Show more settings.

## 2026-10-09 — Show the last 4 characters of the dedicated key

**Decision:** The Eugen dedicated key stays `Mask="true"`. A second always-visible field, Key last 4 (`EUGEN_KEY_LAST4`), must equal the last 4 characters of that key when Write Config From Form is true, or that start stops. It is not written to `login.ini`. The startup line names those 4 characters and not the rest of the key.

**Rationale:** One login can run five servers, and an operator may have two keys across several containers. Unraid's masked field hides the whole value, so the form cannot reveal four characters inside that box. The companion field is what stays readable when the container is opened later.

## 2026-10-09 — Do not claim a 2v2 map accepts eight players

**Decision:** Max Players says the lobby is not locked to the map and that 8 slots on a 2v2 map is untested. Team Size stays the per-side count. The README gives the usual lobby for each size once and does not claim that eight slots work on a 2v2 map. The wrapper still accepts any Max Players from 1 to 20.

**Rationale:** Eugen's Docker Hub text, fetched 2026-10-09, defines `NbMaxPlayer` as how many players can join (maximum 20) and `MaxTeamSize` as the maximum on one side. It never says those must match the size in the scenario ID. Whether `RDPort_JungleLaw_2v2_CONQ` with 8 and 4 opens a 4v4 lobby has not been run.

## 2026-10-10 — Red Dragon ModList version 27

**Decision:** The preset Workshop Mod List is `3811913066/27`. The wrapper warns when that item is listed as `3811913066/0` or `3811913066/15` and still writes that value through. It does not query Steam for a newer `Version`. The next entry keeps `3811913066/27` as the Red Dragon example and makes the template default empty. The entry "Workshop Version read at container start" makes the example `3811913066` and reads `Version` from Steam at each start.

**Rationale:** `Config.ini` for workshop item `3811913066`, read 2026-10-10 from the local Steam library, says `Version = 27`. The author's change note the same day says Mod Version = 27 and 28 scenarios: https://steamcommunity.com/sharedfiles/filedetails/changelog/3811913066. The previous preset `3811913066/15` matched Version 15 on 2026-10-09 and does not match 27. Clients compare the number after the slash with that `Version`. The container has no copy of `Config.ini`, so a later increment has to be copied into the form by hand.

## 2026-10-10 — Base-game defaults, workshop fields start empty

**Decision:** The template defaults are Map `_2x2_Hesse_2vs2_CONQ` and Server Name `WARHOST - Hesse 2v2`. The entry "Placeholder server name" replaces that Server Name. Workshop Mod List and Workshop Mod Tags are empty in both the `Default` attribute and the element text. The Red Dragon values, Map `RDPort_JungleLaw_2v2_CONQ`, `3811913066/27`, and `Maps-Scenarios`, are examples in the Map and Workshop field descriptions and in the README workshop mods section, where Red Dragon is the first row. The wrapper treats an unset variable and `none`, in any case, as empty for both workshop fields. When the list contains `3811913066` and Map does not start with `RDPort_`, the wrapper prints one warning and still writes the list. Max Players `4`, Team Size `2`, and Combat Rule `2` are unchanged. The entry "Workshop Version read at container start" changes the Workshop Mod List example to `3811913066`.

**Rationale:** Unraid's [Helpers.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/Helpers.php), read 2026-10-10, fills a blank `<Config>` value from its `Default` in the edit form (`xmlToVar`) and in the `docker run` variables (`xmlToCommand`). With `Default="3811913066/27"`, a cleared Workshop Mod List came back. On 2026-10-10 the operator reported that a second container, WARHOST2, hosting a base-game map kept writing the Red Dragon mod list and tags after both fields were cleared, and players without the pack could not join. An empty default lets a cleared field stay empty. A container added from the earlier template keeps the old `Default` in its saved `my-<Name>.xml`, so `none` is the opt-out that works there without recreating it. Hesse is a base-game 2v2 Conquest ID from Eugen's Map Base Id table in `README.md`, so a fresh install needs no mod and the preset player counts still fit. The warning does not stop the start because a conversion such as Galactic Divide can run on a base-game map. The 28 Red Dragon scenario IDs read on 2026-10-10 all start with `RDPort_`, so the pack does nothing for any other map.

## 2026-10-10 — Lobby page stays beside the server

**Decision:** `WEB_UI` defaults to `false`. The template default was replaced later the same week; see the 2026-10-11 entry that turns WebUI on. The page code lives in `webui/` on `dev`. `entrypoint-unraid.sh` gains one hook: when the variable is true and `webui/launch.sh` is executable, run it, ignore its exit, and still exec `/server/entrypoint2.sh`. A regular `variables.ini` that already exists is left in place; `login.ini` is still rewritten from the form. The page listens on the game port plus 1000, validates a save, and replaces `variables.ini`. It does not signal the game. Loading a save is an Unraid restart of that container. The Docker WebUI link is `http://[IP]:[PORT:11400]/`. A push of `dev` does not publish the page. It reaches `ghcr.io/suchamoneypit/warhost:latest` only when `dev` is merged to `main` and the image rebuild finishes.

**Rationale:** A page that is the parent of `warno-server`, or that restarts it, can take the match down when the page fails. The hook is fail-open so a missing launcher, a crash, or a taken page port only warns. Eugen's [variables.ini](https://hub.docker.com/r/eugensystems/warno) page, fetched 2026-10-10, is the key list the dropdowns write. Combat rule stays Destruction `1` and Conquest `2` from that page. The in-game labels for income and command and control are the ones recorded from the lobby screens.

## 2026-10-11 — The docker log says whether the lobby page is listening

**Decision:** With Lobby Page off, the wrapper prints `Lobby page is off. Nothing is listening on port N.` With it on, `webui/launch.sh` prints `Lobby page listening on port N.` only after a TCP connection to `127.0.0.1` succeeds and `/proc/net/tcp` shows that port listening on `0.0.0.0`. The server writes its own pid. The ready file is completed after the privilege drop is attempted. If the drop fails, the process stays root, the container log warns that it stayed root, and the page still serves. Once it is serving, the page ignores SIGHUP, so the launcher exiting does not stop it. `WARHOST_WEBUI_DROP_FAIL` is a test seam, not a form field.

**Rationale:** On 2026-10-11 the operator opened the Docker WebUI button and Brave reported `10.0.1.105 refused to connect`. The docker log from that boot shows `warno-server` reaching matchmaking on `71.241.212.203:10400` and never mentions a lobby page. `ghcr.io/suchamoneypit/warhost:latest` was the image from [Actions run 38097617038](https://github.com/suchamoneypit/WARHOST/actions/runs/38097617038) for commit `9dfec47`. Its entrypoint layer does not contain `WEB_UI`. Host networking leaves `[PORT:11400]` as 11400 ([DockerClient.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/DockerClient.php) `getControlURL`, re-read 2026-10-11), so the button opens a port that image does not serve. The next image has to say that in the same log. A failed privilege drop must not close the port after the launcher has already returned.

## 2026-10-11 — v1.10 publishes the WebUI as the lobby editor

**Decision:** `VERSION` is `1.10`. The release workflow tags this publish `v1.10`. The Docker form keeps the settings folder, Eugen login, dedicated key, public WAN IP, WebUI, Game Port, and Write Config From Form. Server name, map, player counts, combat rule, and workshop mods stay in the WebUI. The merged template `<Repository>` is `ghcr.io/suchamoneypit/warhost:latest`. The `dev` template stays on `ghcr.io/suchamoneypit/warhost:dev`.

**Rationale:** The WebUI is the place those lobby fields are edited. A Docker form edit cannot update a `variables.ini` the page already seeded, and the form was harder to read than the page. `1.10` is the two-digit form of 1.1, the same way `1.0` is `v1.00`. The latest tag before this file was `v1.07`. A `VERSION` of `1.01` is below that tag, so the workflow would ignore it and tag `v1.08`.
