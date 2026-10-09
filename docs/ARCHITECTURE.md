# Architecture

This repository is an Unraid template and a settings wrapper around Eugen Systems' official WARNO dedicated-server image. The game server itself stays in `eugensystems/warno`.

Checked against the files in this repo on 2026-10-09, the Docker Hub page [eugensystems/warno](https://hub.docker.com/r/eugensystems/warno), and anonymous registry reads of `eugensystems/warno:latest` and `ghcr.io/suchamoneypit/warno-unraid:latest`. Digests below are from that day and will change when the images are rebuilt.

## Layout

| Path | Role |
| --- | --- |
| `templates/warno-dedicated-server.xml` | Unraid container template |
| `ca_profile.xml` | Community Apps repository profile |
| `Dockerfile` | `FROM eugensystems/warno:latest`, then replaces the entrypoint |
| `entrypoint-unraid.sh` | Writes settings, then execs Eugen's entrypoint |
| `samples/` | Placeholder shapes for the three generated files |
| `tests/entrypoint_test.sh` | Runs the wrapper against a fake upstream entrypoint |
| `scripts/upstream_digest.py` | Prints the Eugen image manifest digest |
| `scripts/check_repo.sh` | Local XML and repository checks |
| `.github/workflows/rebuild-image.yml` | Rebuilds the GHCR image when Eugen's digest changes |
| `.github/workflows/check-repo.yml` | Runs `scripts/check_repo.sh` |
| `docs/INSTALL-UNRAID.md` | First-install walkthrough for Unraid 7 with verification and troubleshooting |
| `docs/UNRAID-TEMPLATE-GUIDE.md` | Generic Unraid template guidance, reusable for other game servers |
| `docs/CURSOR-QUICKSTART.md` | How the Cursor rules, subagents, and commands in `.cursor/` are meant to be used |
| `.cursor/rules/`, `.cursor/agents/`, `.cursor/commands/` | Agent rules (generic workflow, generic Unraid conventions, WARNO project), four subagents, five slash commands |

`.dockerignore` keeps templates, tests, samples, Markdown, and `.github` out of the image build context. The Dockerfile copies only `entrypoint-unraid.sh`.

## Template behavior

Unraid installs `ghcr.io/suchamoneypit/warno-unraid:latest` from `templates/warno-dedicated-server.xml`. The template is `<Container version="2">`. Paths and variables are `<Config>` entries. There is no WebUI.

On start, `WRITE_CONFIG` defaults to true. The wrapper then rewrites these files under the settings directory:

- `login.ini` from `EUGEN_LOGIN` and `EUGEN_DEDICATED_KEY`
- `variables.ini` from the form plus the match defaults hardcoded in `entrypoint-unraid.sh`
- `params_for_ai.json` as two empty deck lists, `0` and `1`

Those files are written mode `600`. `WRITE_CONFIG=false` leaves existing copies in place and exits if any of the three is missing. The wrapper does not mention `admins.ini` or `banned_clients.ini`. The README says the official server creates those two and that this wrapper leaves them alone. That server behavior was not observed here.

The form exposes login, key, public IP, port, server name, map, player counts, team size, combat rule, mod list, mod tags, and the write-config switch. The wrapper also writes fixed match values: `GameType = 0`, `MapRotationType = 0`, `InitMoney = 750`, `TimeLimit = 1200`, `ScoreLimit = 2000`, `WarmupCountdown = 60`, `LoadingTimeMax = 120`, `DeploiementTimeMax = 120`, `DebriefingTimeMax = 60`, `DeltaMaxTeamSize = 0`, `IncomeRate = 3`, `Upkeep = 0`, `AllowObservers = 1`, and `ObserverDelay = 120`.

The preset in the template and sample is a 2v2 Conquest server (`NB_MAX_PLAYER=4`, `MAX_TEAM_SIZE=2`, `COMBAT_RULE=2`) for workshop item `3811913066`, with `MOD_TAG_LIST=Maps-Scenarios`. The Map default is `RDPort_JungleLaw_2v2_CONQ`. `Jungle Law` and `YOUR_*` placeholders are rejected. Base-game scenario IDs are also accepted. For those, Workshop Mod List should be cleared.

## Paths

| Location | Path |
| --- | --- |
| Container settings | `/server/settings` |
| Default Unraid host path | `/mnt/user/appdata/warno/settings` |
| Wrapper entrypoint | `/server/entrypoint-unraid.sh` |
| Upstream entrypoint | `/server/entrypoint2.sh` (`UPSTREAM_ENTRYPOINT` can override it) |

A second server is another container from the same template, with its own name, game port, and settings folder. Eugen's Docker Hub page says one login and key pair can start a maximum of five servers: [Obtaining access key](https://hub.docker.com/r/eugensystems/warno).

## Networking

The template sets `<Network>host</Network>` and defines no port mapping. `EXPOSEDIP` and `EXPOSEDPORT` are environment variables. The default port in the template is `10400`. Eugen's start example uses a placeholder port, so `10400` is a choice of this repository.

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

The manifest for `ghcr.io/suchamoneypit/warno-unraid:latest` was readable without credentials on 2026-10-09 (anonymous token, HTTP 200), so Unraid can pull it. The image layers were not downloaded. Values from the rebuild that followed commit `848a5a4`:

- Manifest digest `sha256:67ea75b2542f2ed924958ba087b6598d5a3b2632885655d523a9187e39138095`
- Created `2026-10-09T08:12:08Z`
- Entrypoint `/server/entrypoint-unraid.sh`, working directory `/server`, no `ExposedPorts`
- Label `warno.upstream.digest` equal to the Eugen digest above

Both GitHub workflows (`Check repository`, `Rebuild WARNO image`) completed successfully for that commit. The repository is public with Issues enabled.

`.github/workflows/rebuild-image.yml` rebuilds that GHCR tag on a daily schedule, on manual dispatch, and on pushes to `main` that change the Dockerfile, wrapper, or workflow. Those pushes always rebuild. The daily schedule, and a manual run with force left false, skip the build when the published image's `warno.upstream.digest` label already matches Eugen's digest.

## External dependencies

- Eugen image and settings reference: https://hub.docker.com/r/eugensystems/warno
- Dedicated login and key: Docker Hub says to email `eugsupport@eugensystems.com` with the EugNet account email, and "We will send you back a login and apikey pair." An existing dedicated key from another Eugen game can be reused. The docs therefore tell users to enter the login from Eugen's reply rather than assuming it equals the email.
- Game: Steam app `1611600`, https://store.steampowered.com/app/1611600/WARNO/
- Map pack: Steam Workshop item `3811913066`, https://steamcommunity.com/sharedfiles/filedetails/?id=3811913066
- Workshop files on a subscribed PC: `steamapps/workshop/content/1611600/3811913066`
- Community Apps submission: https://ca.unraid.net/submit
- Support: https://github.com/suchamoneypit/WARNO-Dedicated-Server-Unraid/issues

The workshop page lists Jungle Law as a 2v2 Conquest scenario name and describes the pack as an unofficial conversion. It does not publish scenario IDs. The 18 IDs in `README.md` are the file names in the mod's `Scenarios/` folder (`<ID>_Assets.dat`, `_Definition.dat`, `_Details.dat`, `_GameData.dat`) as downloaded by Steam to `steamapps/workshop/content/1611600/3811913066/`; they were re-read from those files on 2026-10-09 and matched the README exactly. The page lists "Wonsan Harbour" where the file is `RDPort_WonsanNative_2v2_CONQ`. The mod's `Config.ini` shows `ID = 3811913066` and `Version = 15`; the template's `ModList` uses `/0` per Eugen's "usually always 0". The page showed a download size of 9.264 GB when fetched on 2026-10-09.

Eugen's Docker Hub text documents `login.ini`, `variables.ini`, `params_for_ai.json`, and `maps.ini` (map rotation only). It names the `variables.ini` keys but never defines a `Map` key; the base-game table column is "Map Base Id". The `eugensystems/warno:latest` image read on 2026-10-09 is about 80 MB compressed: Debian base, a 27 MB `warno-server`, default `settings/variables.ini` and `settings/params_for_ai.json`, and no game data layer. What the server fetches at first start was not observed.

`ModList` on that same Docker Hub page tells joining clients to download and enable a missing workshop mod. `entrypoint2.sh` in image digest `sha256:fb498aa82d7b15e3978bac51240e1243be3e19232ba0e66a6d947ec4b4364fe5` does not download files. It runs `warno-server -listenport=$EXPOSEDPORT -ip=$EXPOSEDIP -port=$EXPOSEDPORT -ipmms 178.32.126.73 -portmms 10002`.

Eugen's `variables.ini` reference gives `GameType` `0` as NATO vs PACT. A later sentence on the same page calls that mode Allies vs Axis. The enumerated table is the one this wrapper follows (`GameType = 0`). `NbMaxPlayer` maximum is 20, which the wrapper also enforces. Source: [Configuration file `variables.ini`](https://hub.docker.com/r/eugensystems/warno).

## Unverified

- No Unraid install was run for this document. Host networking, form storage of the key, and Community Apps acceptance are untested here.
- Whether the official server creates `admins.ini` and `banned_clients.ini` was not observed.
- The exact client error for a sixth server was not observed. The documented limit is five.
- The README's LAN exception for Eugen connectivity was not checked against Eugen.
- Whether `warno-server` downloads workshop item `3811913066` onto the server was not observed. The binary contains `GetModPackMountingPoint` and `ModDownloadCanceled`, and it contains no `workshop` string.
- Current Unraid handling of `<br>` inside Overview and Description was not tested. The [template schema thread](https://forums.unraid.net/topic/38619-docker-template-xml-schema/) says Unraid 6.10+ removes HTML tags from those fields. The same thread says Community Applications ignores `<Description>` when `<Overview>` is present.
- The install route in `docs/INSTALL-UNRAID.md` (copy the XML to `/boot/config/plugins/dockerMan/templates-user/`, then **Add Container → Template → User templates**) follows the Community Applications author's [statement](https://forums.unraid.net/topic/112170-allow-template-repositories-to-be-hosted-from-other-sources/) that Unraid 6.10 removed the Template Repositories field. It has not been executed on an Unraid 7 server for this repository.
