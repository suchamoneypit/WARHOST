# Architecture

This repository is WARHOST: an Unraid template and a settings wrapper around Eugen Systems' official WARNO dedicated-server image. The game server itself stays in `eugensystems/warno`.

Checked against the files in this repo on 2026-10-09, the Docker Hub page [eugensystems/warno](https://hub.docker.com/r/eugensystems/warno), and anonymous registry reads of `eugensystems/warno:latest` and `ghcr.io/suchamoneypit/warhost:latest`. Digests below are from that day and will change when the images are rebuilt. The rebuild workflow publishes `ghcr.io/suchamoneypit/warhost:latest` only.

## Layout

| Path | Role |
| --- | --- |
| `templates/warhost.xml` | Unraid container template. Container name `WARHOST`. |
| `ca_profile.xml` | Community Apps repository profile |
| `Dockerfile` | `FROM eugensystems/warno:latest`, then replaces the entrypoint |
| `entrypoint-unraid.sh` | Writes settings, then execs Eugen's entrypoint |
| `samples/` | Placeholder shapes for the three generated files |
| `tests/entrypoint_test.sh` | Runs the wrapper against a fake upstream entrypoint |
| `scripts/upstream_digest.py` | Prints the Eugen image manifest digest |
| `scripts/check_repo.sh` | Local XML and repository checks |
| `scripts/print_template_fetch.sh` | Prints the Unraid terminal command that downloads the template as `my-<Name>.xml` before it is in Community Applications |
| `.github/workflows/rebuild-image.yml` | Rebuilds the GHCR image when Eugen's digest changes |
| `.github/workflows/check-repo.yml` | Runs `scripts/check_repo.sh` |
| `docs/INSTALL-UNRAID.md` | First-install walkthrough for Unraid 7 with verification and troubleshooting |
| `docs/UNRAID-TEMPLATE-GUIDE.md` | Generic Unraid template guidance, reusable for other game servers |
| `docs/CURSOR-QUICKSTART.md` | How the Cursor rules, subagents, and commands in `.cursor/` are meant to be used |
| `.cursor/rules/`, `.cursor/agents/`, `.cursor/commands/` | Agent rules (generic workflow, generic Unraid conventions, WARNO project), five subagents, seven slash commands |

`.dockerignore` keeps templates, tests, samples, Markdown, and `.github` out of the image build context. The Dockerfile copies only `entrypoint-unraid.sh`.

## Template behavior

Unraid installs `ghcr.io/suchamoneypit/warhost:latest` from `templates/warhost.xml`. The template is `<Container version="2">`. `<Name>` is `WARHOST`. `<ExtraSearchTerms>` is `WARNO WARNO server dedicated server game server mods modded`. Paths and variables are `<Config>` entries. The default host folder stays `/mnt/user/appdata/warno/settings`. There is no WebUI.

On start, `WRITE_CONFIG` defaults to true. The wrapper then rewrites these files under the settings directory:

- `login.ini` from `EUGEN_LOGIN` and `EUGEN_DEDICATED_KEY`. The startup line names the last 4 characters of the key. Those characters are not a separate setting.
- `variables.ini` from the form plus the match defaults hardcoded in `entrypoint-unraid.sh`
- `params_for_ai.json` as two empty deck lists, `0` and `1`

Those files are written mode `600`. `WRITE_CONFIG=false` leaves existing copies in place and exits if any of the three is missing. The wrapper does not mention `admins.ini` or `banned_clients.ini`. The README says the official server creates those two and that this wrapper leaves them alone. That server behavior was not observed here.

The form exposes login, key, public IP, port, server name, map, player counts, team size, combat rule, mod list, mod tags, and the write-config switch. The login and the dedicated key use `Mask="false"`. Max Players, Minimum Players, Team Size, and Combat Rule use `Display="always"`. Map, Workshop Mod List, Workshop Mod Tags, and Write Config From Form use `Display="advanced"`. Field descriptions are one or two sentences. Base-game scenario IDs and the named workshop mods are in `README.md`, not in the form. Unraid's [CreateDocker.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/CreateDocker.php) `templateDisplayConfig`, read on 2026-10-09, prints each field description under the input, and appends `Display="advanced"` fields to the Show more settings block. The wrapper also writes fixed match values: `GameType = 0`, `MapRotationType = 0`, `InitMoney = 750`, `TimeLimit = 1200`, `ScoreLimit = 2000`, `WarmupCountdown = 60`, `LoadingTimeMax = 120`, `DeploiementTimeMax = 120`, `DebriefingTimeMax = 60`, `DeltaMaxTeamSize = 0`, `IncomeRate = 3`, `Upkeep = 0`, `AllowObservers = 1`, and `ObserverDelay = 120`.

The preset in the template and sample is a 2v2 Conquest server (`NB_MAX_PLAYER=4`, `MAX_TEAM_SIZE=2`, `COMBAT_RULE=2`) for workshop item `3811913066`, with `MOD_LIST=3811913066/15` and `MOD_TAG_LIST=Maps-Scenarios`. The Map default is `RDPort_JungleLaw_2v2_CONQ`. `Jungle Law` and `YOUR_*` placeholders are rejected. Base-game scenario IDs are also accepted. For those, Workshop Mod List should be cleared. When `ModList` is set, the wrapper prints that clients compare each `id/version` with `Version` in that mod's `Config.ini`, and that the client message does not appear in this log. The pair `3811913066/0` also prints a warning and is still written through. Public WAN IP stays empty. Unraid's [CreateDocker.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/CreateDocker.php), read on 2026-10-09, fills the Add Container form from the template XML and only rewrites the `/config` and `/unraid` path defaults. The install guide points at <https://www.whatismyip.com/>.

## Paths

| Location | Path |
| --- | --- |
| Container settings | `/server/settings` |
| Default Unraid host path | `/mnt/user/appdata/warno/settings` |
| Wrapper entrypoint | `/server/entrypoint-unraid.sh` |
| Upstream entrypoint | `/server/entrypoint2.sh` (`UPSTREAM_ENTRYPOINT` can override it) |

A second server is another container from the same template, with its own name, Game Port (the previous port plus 1), Server Name, and settings folder. The first host folder stays `/mnt/user/appdata/warno/settings`. An added server uses its own folder, for example `/mnt/user/appdata/warno/10401/settings`. Those folders hold the ini files. The wrapper takes an exclusive `flock` on `warhost.lock` in that directory and holds the fd across `exec` until the server process exits. If `flock` is missing, it warns and continues. Eugen's Docker Hub page says one login and key pair can start a maximum of five servers: [Obtaining access key](https://hub.docker.com/r/eugensystems/warno). Fifteen servers need three pairs, fifty need ten, and one hundred needs twenty. The published image is one shared copy. There is no game-library volume.

## Networking

The template sets `<Network>host</Network>` and defines no port mapping. `EXPOSEDIP` and `EXPOSEDPORT` are environment variables read on each start. The default port in the template is `10400`. Eugen's start example uses a placeholder port, so `10400` is a choice of this repository. Editing the container and applying a new `EXPOSEDPORT` changes the listen port; the router forward has to use the same number. The next container's Game Port is that number plus 1. One server uses that one port: forward it as TCP and UDP, not as the port and the port plus 1. Players join by Server Name. Eugen's page does not say the port is fixed after the first start.

Before exec, the wrapper reads `tcp`, `tcp6`, `udp`, and `udp6` under `WARHOST_PORT_TABLE` (default `/proc/net`, which host networking shares with the host). It stops if this Game Port is a local TCP socket in state `0A` (LISTEN) or a local UDP socket in any state. TIME_WAIT and the other TCP states do not count, so a port left behind after a stop does not force a new folder or Server Name. The first line of each file is skipped as a header. Only the local-address column is compared. `WARHOST_PORT_TABLE` is not a template field. Two containers started in the same moment can both pass this check.

Eugen recommends host networking and says to forward both TCP and UDP to the exposed port: [Starting docker container](https://hub.docker.com/r/eugensystems/warno). The image config read on 2026-10-09 has no `ExposedPorts`.

The README says outbound internet is required to reach Eugen except for LAN use. Docker Hub does not state that LAN exception. Treat it as a statement in this repository.

RCON is unset. Eugen documents `-rcon_password` and `-rcon_port` as arguments to the official container. The template leaves `PostArgs` empty. The wrapper forwards any arguments it receives to the upstream entrypoint.

## Image chain

`Dockerfile` bases the Unraid image on `eugensystems/warno:latest` and sets the entrypoint to the wrapper. The wrapper then execs the upstream script.

Registry config for `eugensystems/warno:latest` on 2026-10-09:

- Manifest digest `sha256:fb498aa82d7b15e3978bac51240e1243be3e19232ba0e66a6d947ec4b4364fe5`
- Config created `2026-09-17T09:35:31Z`
- Working directory `/server`
- Entrypoint `./entrypoint2.sh`

That entrypoint plus the working directory is the absolute path `/server/entrypoint2.sh` used by this wrapper. The script body was read from the image layer; its `warno-server` command line is quoted under External dependencies below.

The wrapper image manifest was readable without credentials on 2026-10-09 at `ghcr.io/suchamoneypit/warno-unraid:latest` (anonymous token, HTTP 200). The rebuild workflow no longer publishes that name. It publishes `ghcr.io/suchamoneypit/warhost:latest`. Values below are from that `warno-unraid` read, the rebuild that followed commit `848a5a4`:

- Manifest digest `sha256:67ea75b2542f2ed924958ba087b6598d5a3b2632885655d523a9187e39138095`
- Created `2026-10-09T08:12:08Z`
- Entrypoint `/server/entrypoint-unraid.sh`, working directory `/server`, no `ExposedPorts`
- Label `warno.upstream.digest` equal to the Eugen digest above

A later anonymous read of `ghcr.io/suchamoneypit/warhost:latest`, after [Actions run 37992605391](https://github.com/suchamoneypit/WARHOST/actions/runs/37992605391) for commit `e005c64` finished green, gave manifest digest `sha256:156858f3939a977e0329f56fe78c960fd3e39d41cb9486a2868ef1efb4c01847`, created `2026-10-09T21:48:01Z`. The `entrypoint-unraid.sh` layer from that manifest does not contain `EUGEN_KEY_LAST4` or `Set Key last 4`. The same run's first attempt failed in Build and push with Docker Hub `429 Too Many Requests` and left the previous image in place (created `2026-10-09T20:23:25Z`). That image's entrypoint still died when `EUGEN_KEY_LAST4` was empty. The template on `main` had already dropped that field, so a fresh install during the gap stopped with `Set Key last 4 to the last 4 characters of the Eugen dedicated key.`

Both GitHub workflows (`Check repository`, `Rebuild WARNO image`) completed successfully for commit `848a5a4`. The workflow file is now named `Rebuild WARHOST image`. The repository is public with Issues enabled. The GitHub repository is `WARHOST`. `https://github.com/suchamoneypit/WARNO-Dedicated-Server-Unraid` returned HTTP 301 to that name on 2026-10-09.

`.github/workflows/rebuild-image.yml` rebuilds that GHCR tag on a daily schedule, on manual dispatch, and on pushes to `main` that change the Dockerfile, wrapper, or workflow. Those pushes always rebuild. The daily schedule, and a manual run with force left false, skip the build when the published image's `warno.upstream.digest` label already matches Eugen's digest.

## External dependencies

- Eugen image and settings reference: https://hub.docker.com/r/eugensystems/warno
- Dedicated login and key: Docker Hub says to email `eugsupport@eugensystems.com` with the EugNet account email, and "We will send you back a login and apikey pair." An existing dedicated key from another Eugen game can be reused. The docs therefore tell users to enter the login from Eugen's reply rather than assuming it equals the email.
- Game: Steam app `1611600`, https://store.steampowered.com/app/1611600/WARNO/
- Map pack: Steam Workshop item `3811913066`, https://steamcommunity.com/sharedfiles/filedetails/?id=3811913066
- Other packs named in `README.md`, without scenario IDs in this repo: [3363584349](https://steamcommunity.com/sharedfiles/filedetails/?id=3363584349), [3474588989](https://steamcommunity.com/sharedfiles/filedetails/?id=3474588989), [3705706772](https://steamcommunity.com/sharedfiles/filedetails/?id=3705706772), [3415339374](https://steamcommunity.com/sharedfiles/filedetails/?id=3415339374), [3762638679](https://steamcommunity.com/sharedfiles/filedetails/?id=3762638679)
- Conversions named in `README.md`, without a `Config.ini` `Version` in this repo: [Galactic Divide](https://steamcommunity.com/sharedfiles/filedetails/?id=3595948209) (`3595948209`) and [A World in Flames](https://steamcommunity.com/sharedfiles/filedetails/?id=3388575848) (`3388575848`). Pages fetched on 2026-10-09. Galactic Divide's page calls it a total conversion and links the tags Gameplay, Interface, Sound, Scenarios, and Maps. A World in Flames's page calls it an overhaul for the modern day and links Gameplay and Interface. Neither page states a scenario ID.
- Workshop files on a subscribed PC: `steamapps/workshop/content/1611600/3811913066`
- Community Apps submission: https://ca.unraid.net/submit
- Support: https://github.com/suchamoneypit/WARHOST/issues

The workshop page lists Jungle Law as a 2v2 Conquest scenario name and describes the pack as an unofficial conversion. It does not publish scenario IDs. The 102 base-game IDs in `README.md` are Eugen's Map Base Id column. They were copied from the template text that quoted the Docker Hub table read on 2026-10-09, then removed from the form. The 18 Red Dragon IDs in `README.md` are the file names in the mod's `Scenarios/` folder (`<ID>_Assets.dat`, `_Definition.dat`, `_Details.dat`, `_GameData.dat`) as downloaded by Steam to `steamapps/workshop/content/1611600/3811913066/`; they were re-read from those files on 2026-10-09 and matched the README exactly. The page lists "Wonsan Harbour" where the file is `RDPort_WonsanNative_2v2_CONQ`. The mod's `Config.ini` shows `ID = 3811913066` and `Version = 15`, re-read on 2026-10-09; the comment says to increment `Version` when an update is incompatible. The template's `ModList` is `3811913066/15`. Eugen's Docker Hub page says the `ModList` version "is usually always 0". On 2026-10-09 the operator started with `3811913066/0`: the log showed `Variable ModList set to "3811913066/0"` and `Connection to match making server validated`, and no line about the rejected join. The operator reported that `3811913066/15` is what let a client join. The page showed a download size of 9.264 GB when fetched on 2026-10-09.

Eugen's Docker Hub text documents `login.ini`, `variables.ini`, `params_for_ai.json`, and `maps.ini` (map rotation only). It names the `variables.ini` keys but never defines a `Map` key; the base-game table column is "Map Base Id". The `eugensystems/warno:latest` image read on 2026-10-09 is about 80 MB compressed: Debian base, a 27 MB `warno-server`, default `settings/variables.ini` and `settings/params_for_ai.json`, and no game data layer. What the server fetches at first start was not observed.

`ModList` on that same Docker Hub page tells joining clients to download and enable a missing workshop mod. `entrypoint2.sh` in image digest `sha256:fb498aa82d7b15e3978bac51240e1243be3e19232ba0e66a6d947ec4b4364fe5` does not download files. It runs `warno-server -listenport=$EXPOSEDPORT -ip=$EXPOSEDIP -port=$EXPOSEDPORT -ipmms 178.32.126.73 -portmms 10002`.

Eugen's `variables.ini` reference gives `GameType` `0` as NATO vs PACT. A later sentence on the same page calls that mode Allies vs Axis. The enumerated table is the one this wrapper follows (`GameType = 0`). `NbMaxPlayer` maximum is 20, which the wrapper also enforces. `MaxTeamSize` is only "Maximum number of players in each team." That page never says either value must match the size token in the scenario ID. Separate Map Base Ids exist for sizes such as `_2vs2_` and `_4vs4_`. Source: [Configuration file `variables.ini`](https://hub.docker.com/r/eugensystems/warno), registry `full_description` fetched 2026-10-09 (`last_updated` 2026-09-17) from <https://hub.docker.com/v2/repositories/eugensystems/warno/>.

## Unverified

- No completed Unraid install is recorded here. On 2026-10-09 the operator added a container from `my-WARHOST.xml` on Unraid 7.3.3. A fresh install while the 20:23 image was still published stopped on the old Key last 4 check. After the 21:48 image, the operator reported that stop was gone. This document did not see the healthy `warno-server` log, the settings files, or a Jungle Law lobby. Community Apps acceptance is untested.
- Whether the official server creates `admins.ini` and `banned_clients.ini` was not observed.
- The exact client error for a sixth server was not observed. The documented limit is five.
- The README's LAN exception for Eugen connectivity was not checked against Eugen.
- Whether `warno-server` downloads workshop item `3811913066` onto the server was not observed. The binary contains `GetModPackMountingPoint` and `ModDownloadCanceled`, and it contains no `workshop` string. There is no shared game-data mount until a running server shows a large directory and its path. RAM per `warno-server` is not documented.
- Whether `flock` on an Unraid `/mnt/user` share keeps two containers out of one settings folder was not tried on a server. `tests/entrypoint_test.sh` holds the lock on a local file.
- The Overview no longer contains `<br>`. [CreateDocker.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/CreateDocker.php), read on 2026-10-09, converts `[` `]` to tags, replaces `<br>` with a newline, runs `strip_tags`, and the basic view then turns newlines into line breaks. The operator had seen the letters `br` in the previous Overview. Whether the new paragraphs break correctly on their Unraid screen has not been checked. The [template schema thread](https://forums.unraid.net/topic/38619-docker-template-xml-schema/) says Community Applications ignores `<Description>` when `<Overview>` is present.
- Whether `Map=RDPort_JungleLaw_2v2_CONQ` with `NbMaxPlayer=8` and `MaxTeamSize=4` opens an 8-player lobby. Eugen's page does not forbid it and does not confirm it. The server binary was not run with that combination.
- Scenario IDs and `Config.ini` `Version` for workshop items `3363584349`, `3474588989`, `3705706772`, `3415339374`, `3762638679`, `3595948209`, and `3388575848`. Their pages, fetched on 2026-10-09, do not publish either. Only `3811913066` is present under the local Steam library.
- The install route in `docs/INSTALL-UNRAID.md` follows the Community Applications author's [statement](https://forums.unraid.net/topic/112170-allow-template-repositories-to-be-hosted-from-other-sources/) that Unraid 6.10 removed the Template Repositories field. `scripts/print_template_fetch.sh` prints the download. The Template dropdown label is the flash filename with `my-` removed ([CreateDocker.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/CreateDocker.php)); Unraid's own save path is `my-<Name>.xml` and keeps that case ([DockerClient.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/DockerClient.php) `getUserTemplatePath`). Both files were read from webgui `master` on 2026-10-09. The operator reported that `warno-dedicated-server.xml` showed up lowercase. On 2026-10-09 Unraid 7.3.3 opened Add Container at `user:/boot/config/plugins/dockerMan/templates-user/my-WARHOST.xml` and the dropdown label was WARHOST. That file kept the previous form, including Key last 4, until it was deleted and the curl from `main` was run again. Apply on an Add Container tab that was already open writes that tab back over the file.
