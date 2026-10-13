# Architecture

WARHOST is an Unraid template and a settings wrapper around Eugen Systems' official WARNO dedicated-server image, `eugensystems/warno`. The game server itself stays in Eugen's image. This page states how the repository works now. File roles are in `docs/PROJECT-MAP.md`. The dated reads, measurements, and operator observations behind these statements are in `docs/EVIDENCE.md`, and the dates of each source are under Sources below.

## Images and releases

`.github/workflows/rebuild-image.yml` publishes `ghcr.io/suchamoneypit/warhost:latest` from `main` and `ghcr.io/suchamoneypit/warhost:dev` from `dev`. A push to either branch that changes `Dockerfile`, `entrypoint-unraid.sh`, `webui/`, or that workflow always rebuilds. A daily schedule and a manual run with force left false skip the build when the published image's `warno.upstream.digest` label already matches Eugen's digest. The `main` template's `<Repository>` is `:latest` and the `dev` template's is `:dev`. A publish sets the merged element to `:latest` and leaves `:dev` on `dev`.

`.github/workflows/release.yml` runs on every push to `main`. With no version tags the first release is `v0.90`. Otherwise it adds one to the minor part (`v0.90` then `v0.91`, `v0.99` then `v1.00`). A `VERSION` file higher than the latest tag is used as written (`1.0` is `v1.00`). A file equal to or below the latest tag is ignored and the latest tag is incremented. The workflow creates an annotated tag only when that name is missing; a commit that already has a version tag keeps the lowest one. It opens a GitHub Release whose notes come from `scripts/release_notes.py`: a written summary for `v0.90` through `v1.11`, and for a later tag the commit subjects since the previous version tag, with the compare link at the bottom. It does not push a commit. Daily and manual image rebuilds do not create a version.

`Dockerfile` builds `FROM eugensystems/warno:latest`. It downloads `DepotDownloader-linux-x64.zip` from release [DepotDownloader_3.4.0](https://github.com/SteamRE/DepotDownloader/releases/tag/DepotDownloader_3.4.0), checks SHA-256 `a999dec66b4850fc961bd50366696d23c2d0fad7b18790e6a5647b2f19097a53`, and unpacks it with `python3 -m zipfile` into `/opt/depotdownloader` with its GPL-2.0 `LICENSE`; `/usr/local/bin/DepotDownloader` links to the self-contained binary. It copies `entrypoint-unraid.sh` and `webui/`, adds the `warhost-web` user, and sets the wrapper as the entrypoint. It leaves `org.opencontainers.image.licenses` unset. `LICENSE` (MIT) covers the repository files only, and Community Apps treats the image license as separate ([submission help](https://ca.unraid.net/submit/help)). `.dockerignore` keeps templates, tests, samples, Markdown, `.github`, and `webui/previews/` out of the build context.

Eugen's image, at manifest digest `sha256:fb498aa82d7b15e3978bac51240e1243be3e19232ba0e66a6d947ec4b4364fe5` (config created `2026-09-17T09:35:31Z`), has working directory `/server` and entrypoint `./entrypoint2.sh`, so the wrapper runs `/server/entrypoint2.sh` (`UPSTREAM_ENTRYPOINT` can override it). That script does not download files. It runs `warno-server -listenport=$EXPOSEDPORT -ip=$EXPOSEDIP -port=$EXPOSEDPORT -ipmms 178.32.126.73 -portmms 10002`. The image has `wget`, `sha256sum`, `python3`, `timeout`, and `flock`; it has no `curl`, `unzip`, or ICU library; its `/bin/sh` is `dash`; it declares no `ExposedPorts`. The wrapper sets `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` because ICU is absent. `python3 scripts/upstream_digest.py` prints the current digest.

## Template and form

Community Applications lists the template from `main`, and an Unraid install has run with the container staying up, the key only in the settings files, and Hesse as the running map (both maintainer reports, 2026-10-13). The flash-drive copy from `scripts/print_template_fetch.sh` is the route for `dev`. `templates/warhost.xml` is `<Container version="2">` with `<Name>` `WARHOST`, `<Network>host</Network>`, and no port mapping. `<ExtraSearchTerms>` is `WARNO WARNO server dedicated server game server mods modded`. `<ReadMe>` and `<License>` are the raw `README.md` and `LICENSE` URLs on `main`. `<WebUI>` is `http://[IP]:[PORT:11400]/`. On host networking Unraid's `getControlURL` ([DockerClient.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/DockerClient.php)) leaves `[PORT:11400]` as 11400, so that button matches the container on Game Port `10400`. Another container's page is on its own Game Port plus 1000.

The form has seven fields:

- Settings Folder, container path `/server/settings`, default host folder `/mnt/user/appdata/warno/10400/settings`.
- Eugen Login (`EUGEN_LOGIN`) and Eugen Dedicated Key (`EUGEN_DEDICATED_KEY`), both `Mask="false"`.
- Public WAN IP (`EXPOSEDIP`), empty. The install guide points at <https://www.whatismyip.com/>.
- WebUI (`WEB_UI`), `Display="always"`, default `true`, after Public WAN IP. An unset `WEB_UI` still means off in the wrapper.
- Game Port (`EXPOSEDPORT`), default `10400`.
- Write Config From Form (`WRITE_CONFIG`), `Display="advanced"`, default `true`.

Unraid's `templateDisplayConfig` ([CreateDocker.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/CreateDocker.php)) prints each field description under its input and appends `Display="advanced"` fields to Show more settings. Unraid fills the Add Container form from the template XML and only rewrites the `/config` and `/unraid` path defaults. In the Overview, `[` and `]` become tags, `<br>` becomes a newline, `strip_tags` runs, and the basic view turns newlines into line breaks. Field descriptions are one or two sentences; base-game scenario IDs and the named workshop mods are in `README.md`.

Server name, map, player counts, combat rule, and workshop mods are edited in the WebUI, not on the form. A saved container that still passes `SERVER_NAME`, `MAP`, `NB_MAX_PLAYER`, `NB_MIN_PLAYER`, `MAX_TEAM_SIZE`, `COMBAT_RULE`, `MOD_LIST`, or `MOD_TAG_LIST` still starts. The wrapper prints `Lobby settings on the Docker template are ignored. Change the server in the WebUI.` and does not apply those values.

## Start-up

With `WRITE_CONFIG` true, the wrapper writes these files in the settings folder:

- `login.ini` from `EUGEN_LOGIN` and `EUGEN_DEDICATED_KEY`, on every start. The startup line names the last 4 characters of the key and nothing else of the key or the login.
- `variables.ini` only when that file is missing, from the seed in `entrypoint-unraid.sh`. An existing regular file is kept, except that a bare Workshop id in its `ModList` is rewritten as `id/Version` (see Workshop Version at start). A symlink is replaced with the seed instead of followed.
- `params_for_ai.json` as two empty deck lists, `0` and `1`, only when that file is missing or a symlink. An existing regular file is kept. A directory at that name stops the start.
- `warhost-workshop-versions.txt`, only when `ModList` holds a bare id.

The seed is a 2v2 Conquest server: server name `WARHOST - default server name`, map `_2x2_Hesse_2vs2_CONQ`, `NbMaxPlayer = 4`, `NbMinPlayer = 2`, `MaxTeamSize = 2`, `CombatRule = 2`, no `ModList` or `ModTagList` line, and `GameType = 0`, `MapRotationType = 0`, `InitMoney = 750`, `TimeLimit = 1200`, `ScoreLimit = 2000`, `WarmupCountdown = 60`, `LoadingTimeMax = 120`, `DeploiementTimeMax = 120`, `DebriefingTimeMax = 60`, `DeltaMaxTeamSize = 0`, `IncomeRate = 3`, `Upkeep = 0`, `AllowObservers = 1`, `ObserverDelay = 120`. `samples/variables.ini.example` has the same values.

The files are mode `600`. The wrapper sets `umask 077`, creates a private mode-`700` `.warhost-stage.*` directory in the settings folder, writes the files there, and renames them into place. A symlink at a final name is removed instead of followed; a directory at a final name stops the start. The stage directory is removed on exit and on `HUP`, `INT`, and `TERM`. After `warhost.lock` is held, leftover real directories with that prefix are removed and symlinks with that prefix are left. A crash, `SIGKILL`, or power loss can leave one until the next locked start. `WARHOST_STAGING_HOLD` is a test seam: when it names an existing file, the wrapper waits before the rename. `WRITE_CONFIG=false` leaves existing copies in place, sets `login.ini` to mode `600`, and exits if any of the three files is missing.

Warnings about `variables.ini`, none of which stop the start:

- When `ModList` is set, clients compare each `id/version` with `Version` in that mod's `Config.ini`, and the client's refusal does not appear in this log. The wrapper says so.
- When `ModList` contains `3811913066` and Map does not start with `RDPort_`, players without that mod cannot join. That warning replaces the version warning, and the list is kept.
- On a Red Dragon map, the pairs `3811913066/0` and `3811913066/15` warn and stay in the file. A `Version` read from Steam never warns.
- When `ModList` is empty and Map is not one of the 102 base-game scenario IDs copied into the wrapper from the README table, it warns once.
- When `ModTagList` is set and `ModList` is empty, it notes that tags are written and do not select a mod.

The README workshop table gives the Red Dragon example: map `RDPort_JungleLaw_2v2_CONQ` with `3811913066` and tags `Maps-Scenarios`.

With `WEB_UI=true`, after the write the wrapper runs `webui/launch.sh` if it is executable, ignores a failure or a taken page port, and still starts `/server/entrypoint2.sh`. The launcher prints `WebUI listening on port N.` after a connection to `127.0.0.1` succeeds and `/proc/net/tcp` shows that port in state `0A` on `0.0.0.0`. With the page off the log says `WebUI is off. Nothing is listening on port N.`, or `WebUI is off. Port N is already in use.` when that port is already a local socket. The ready file is written after the drop to the `warhost-web` user is attempted. `WARHOST_WEBUI_DROP_FAIL` is a test seam: the drop fails, the process stays root, the log warns that it stayed root, and the page still serves. While the page runs, `variables.ini` and a regular `params_for_ai.json` are mode `644` so the page user can read them. `login.ini` stays mode `600` and the page does not read it. The wrapper does not touch `admins.ini` or `banned_clients.ini`.

## WebUI

The page listens on the Game Port plus 1000 and replaces `variables.ini` on save. A PvE setup save also replaces `params_for_ai.json`; a PvP save does not. Save leaves the match running.

- Workshop Maps is the map-pack checklist. Full conversions and other mods, beside it, lists Galactic Divide and A World in Flames from the catalog `mods` array. Checking a pack shows its maps. A label adds `by` and the catalog author when one is set.
- A save writes checked catalog ids as bare ids, keeps a checked id that is not in the catalog, derives `ModTagList` from the checked mods, and rejects a modded map whose pack is unchecked.
- Choosing a map fills `NbMaxPlayer`, `NbMinPlayer`, and `MaxTeamSize` from the scenario (`players`, `team`, and a minimum of 2 when `players` is at least 2). PvP keeps those three editable; PvE hides them and writes `CoopVsAI`, the human and AI counts, and `DeltaMaxTeamSize`.
- A catalog map offers only its own combat rule.
- The Scenic view and Tactical zones slots show Overview and Preview from `webui/previews/` when `index.json` names that map. One pair per battlefield is shared by every scenario ID with that stem. `scripts/extract_map_previews.py` fills that folder from a local WARNO install; it is gitignored and not in the image, so the published page shows the text labels.

Save and restart. The wrapper stays the container's PID 1. It starts `/server/entrypoint2.sh` in its own session when `setsid` exists and waits for it. A normal exit stops the container. `SIGTERM` and `SIGINT` stop that session and the wrapper exits. `SIGUSR1` stops that session and the wrapper `exec`s itself, so `login.ini` is rewritten, a bare Workshop id is resolved again, and the server starts on the saved `variables.ini`. The page is in its own session and keeps listening; `WARHOST_WEBUI_KEEP` is set only for that re-exec, and the log then says `WebUI still listening on port N.` The page has no Docker socket. Its root helper sends `SIGUSR1` only when `.warhost-supervisor.pid` in the settings folder names a process whose command is `entrypoint-unraid.sh`. Otherwise a changed form is still saved and the page says `This page cannot restart the container. Restart it in Unraid to load the save.`

## Paths and several servers

| Location | Path |
| --- | --- |
| Container settings | `/server/settings` |
| Default Unraid host path | `/mnt/user/appdata/warno/10400/settings` |
| Wrapper entrypoint | `/server/entrypoint-unraid.sh` |
| Upstream entrypoint | `/server/entrypoint2.sh` |

A second server is another container from the same template with its own name, a Game Port one higher than the previous one, its own server name set in the WebUI, and its own settings folder, for example `/mnt/user/appdata/warno/10401/settings`. The wrapper takes an exclusive `flock` on `warhost.lock` in that folder and holds it across `exec` until the server exits; if `flock` is missing it warns and continues. One login and key pair starts at most five servers ([Obtaining access key](https://hub.docker.com/r/eugensystems/warno)). The image is one shared copy, and there is no game-library volume.

## Networking

Eugen recommends host networking. The template uses it with no port mapping. `EXPOSEDIP` and `EXPOSEDPORT` are read on each start. `10400` is this repository's default; Eugen's start example uses a placeholder. Applying a new `EXPOSEDPORT` changes the listen port, and the router forward must use the same number. One server uses one port, forwarded as TCP and UDP ([Starting docker container](https://hub.docker.com/r/eugensystems/warno)). Players join by server name. Eugen's page does not say the port is fixed after the first start.

Before exec, the wrapper reads `tcp`, `tcp6`, `udp`, and `udp6` under `WARHOST_PORT_TABLE` (default `/proc/net`, which host networking shares with the host). It stops if the Game Port is a local TCP socket in state `0A` (LISTEN) or a local UDP socket in any state. TIME_WAIT and other TCP states do not count, so a port left behind after a stop does not force a new folder. The header line is skipped and only the local-address column is compared. `WARHOST_PORT_TABLE` is a test seam. Two containers started in the same moment can both pass this check.

RCON is unset. Eugen documents `-rcon_password` and `-rcon_port` as container arguments. The template leaves `PostArgs` empty, and the wrapper forwards any arguments it receives to the upstream entrypoint.

## Workshop Version at start

A `ModList` entry without `/` is a bare id. After the port and lock checks, and only when `variables.ini` already exists, the wrapper resolves each bare id in list order and rewrites the line as `id/Version`. A typed `id/version` is a pin, left as typed, with no Steam call. A WebUI save writes catalog ids as bare ids, so the next start reads `Version`. `WRITE_CONFIG=false` resolves nothing. The check runs once per start, never during a match; Save and restart is a new start. A missing `variables.ini` is seeded with no mods and does not contact Steam.

`warhost-workshop-versions.txt` holds one line per bare id from the last start: `id time_updated Version`. It is staged and renamed like the other files and is not followed when it is a symlink. A directory at that name is left in place with a warning, and the start continues without saving. The wrapper asks Steam's `GetPublishedFileDetails` (`POST https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/` with `itemcount=1&publishedfileids%5B0%5D=<id>`, no key) for `time_updated`. That response has no `Version`. When `time_updated` equals the saved time, the saved `Version` is written and nothing is downloaded. When Steam gives no time and a line exists, the saved `Version` is written with a warning.

Otherwise the wrapper runs `timeout 300 DepotDownloader -app 1611600 -pubfile <id> -filelist <list> -dir <dir>/item` with no Steam account. The list holds only `Config.ini`. `<dir>` is a new mode-`700` `.warhost-stage.*` directory in the settings folder and is also `HOME`, `TMPDIR`, and the working directory. DepotDownloader runs under `env -i` with only `PATH`, `HOME`, `TMPDIR`, and two .NET settings, so it never receives the Eugen login or key. The wrapper reads the first `Version = <digits>` line, requires `Config.ini` on disk rather than trusting the exit status, and removes `<dir>` before the next id, also after a failure and on `HUP`, `INT`, and `TERM`. When the fetch fails and a line exists, the saved `Version` is written with a warning and the saved time is kept, so the next start tries again. With no line, the start stops after printing the last 5 lines of DepotDownloader's output and the reason. The `ModList` number is the mod's `Config.ini` `Version`, not `ModGenVersion`.

## Eugen settings reference

Eugen's Docker Hub page documents `login.ini`, `variables.ini`, `params_for_ai.json`, and `maps.ini` (map rotation only). It names the `variables.ini` keys but never defines a `Map` key; the base-game table column is "Map Base Id". The wrapper follows the enumerated `GameType` table (`0`). `NbMaxPlayer` is at most 20, which the wrapper enforces. `MaxTeamSize` is one cap for each team and is not tied to the size token in the scenario ID. `CoopVsAI` is `0` off, `1` humans on the first team, `2` humans on the second; `AutoFillAI` cannot be combined with it and is not written. `params_for_ai.json` holds deck name, deck code, and `iaLevel` 1 through 6 for sides `0` and `1`. `ModList` tells joining clients to download and enable a missing mod; the server does not download it.

## External dependencies

- Eugen image and settings reference: <https://hub.docker.com/r/eugensystems/warno>
- Dedicated login and key: email `eugsupport@eugensystems.com` with the EugNet account email; Eugen replies with a login and apikey pair. An existing dedicated key from another Eugen game can be reused. The docs tell users to enter the login from Eugen's reply rather than assuming it equals the email.
- DepotDownloader, GPL-2.0: <https://github.com/SteamRE/DepotDownloader>
- Game: Steam app `1611600`, <https://store.steampowered.com/app/1611600/WARNO/>
- Workshop items named in `README.md`: map packs [3811913066](https://steamcommunity.com/sharedfiles/filedetails/?id=3811913066) (Red Dragon), [3363584349](https://steamcommunity.com/sharedfiles/filedetails/?id=3363584349), [3474588989](https://steamcommunity.com/sharedfiles/filedetails/?id=3474588989), [3705706772](https://steamcommunity.com/sharedfiles/filedetails/?id=3705706772), [3415339374](https://steamcommunity.com/sharedfiles/filedetails/?id=3415339374), [3762638679](https://steamcommunity.com/sharedfiles/filedetails/?id=3762638679); conversions [Galactic Divide](https://steamcommunity.com/sharedfiles/filedetails/?id=3595948209) and [A World in Flames](https://steamcommunity.com/sharedfiles/filedetails/?id=3388575848). The Workshop pages publish neither scenario IDs nor `Version`. Both come from `Config.ini` and the file names in `Scenarios/` under `steamapps/workshop/content/1611600/<id>` on a subscribed PC; `scripts/list_workshop_mods.py` reads them.
- Unraid webgui: [CreateDocker.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/CreateDocker.php), [DockerClient.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/DockerClient.php), [Helpers.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/Helpers.php)
- License: GitHub detects the MIT `LICENSE` ([licensing a repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)), and the GitHub API reports `license.spdx_id` `MIT`. The Docker Hub API for `eugensystems/warno` states no license.
- Community Apps: [submit](https://ca.unraid.net/submit), [help](https://ca.unraid.net/submit/help), [repository XML](https://ca.unraid.net/submit/help/repository-xml), [repository info XML](https://ca.unraid.net/submit/help/repository-info-xml), [XML field reference](https://ca.unraid.net/submit/help/xml-field-reference), [builders](https://ca.unraid.net/submit/help/builders), [starter repository](https://github.com/unraid/unraid-community-apps-starter), [template schema thread](https://forums.unraid.net/topic/38619-docker-template-xml-schema/)
- Map textures: Eugen's map guide names Overview as the lobby texture and Preview as the top-down texture ([complete map modding guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3352892580)).
- Support: <https://github.com/suchamoneypit/WARHOST/issues>

## Unverified

Each item has its observations in `docs/EVIDENCE.md` under Observations and open questions.

- The WebUI privilege drop and Save and restart have not run inside the published image on Unraid. That `entrypoint2.sh` stays in the foreground for a whole match was inferred from a container that stayed up while `warno-server` was online, not from the script.
- Whether `warno-server` keeps a loaded match after `variables.ini` is replaced.
- Whether an 8-player lobby opens on a 2v2 scenario, and whether `CoopVsAI` spawns more AI than humans.
- Whether `warno-server` downloads workshop items onto the server, and its RAM use.
- Whether the official server creates `admins.ini` and `banned_clients.ini`, the client error for a sixth server, and the README's statement that the server needs Eugen's master server with no offline LAN play.
- A bare Workshop id has not been resolved on a running WARHOST container, and no container has run the image with DepotDownloader.
- Whether `Upkeep` 5 and 7 and `IncomeRate` 0 through 5 match the WebUI dropdown labels.
- Whether the Overview paragraphs break correctly on an Unraid screen.
- Whether the operator's `params_for_ai.json` log line was the empty deck lists.

## Sources

When each source was last read. Re-fetch before relying on a value that may have changed.

- Docker Hub page and registry `full_description` for `eugensystems/warno` (`last_updated` 2026-09-17): 2026-10-09, `variables.ini` keys re-read 2026-10-10.
- `eugensystems/warno:latest` registry config, digest, and layers: 2026-10-09.
- Unraid webgui `master` `CreateDocker.php` and `DockerClient.php`: 2026-10-09; `getControlURL` re-read 2026-10-11. `Helpers.php`: 2026-10-10.
- DepotDownloader 3.4.0 release and source: 2026-10-10.
- Community Apps help pages, the GitHub license API, and the starter repository: 2026-10-09. The linked `Squidly271/community.applications` README URL returned HTTP 404 that day; the Unraid org copy of that plugin has no root README.
- Workshop `Config.ini` and `Scenarios/` in the local Steam library: 2026-10-09 and 2026-10-10. Workshop creator names: 2026-10-11.
