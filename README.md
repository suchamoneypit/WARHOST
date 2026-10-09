# WARNO dedicated server for Unraid

Unraid template for one [WARNO](https://store.steampowered.com/app/1611600/WARNO/) dedicated server per container. The install form takes your Eugen login and dedicated key and writes `login.ini`, `variables.ini`, and `params_for_ai.json`. The container then runs the entrypoint from the official `eugensystems/warno` image.

The preset is a 2v2 Conquest server for Jungle Law in the [Red Dragon map pack](https://steamcommunity.com/sharedfiles/filedetails/?id=3811913066) (workshop item `3811913066`).

## Before you install

Email `eugsupport@eugensystems.com` and ask for a dedicated-server key. Use the email on your EugNet account. That same email is the Eugen Login on the form. Eugen emails the key. Eugen answers manually, and one login/key pair can run five servers.

Eugen recommends host networking, and this container uses it, so Unraid does not show a Docker port mapping. Port forward the game port TCP/UDP to your Unraid server. The server also needs outbound internet access so it can reach Eugen (not for LAN usage).

## Install

Community Apps listing comes after this template has been tested on a running server. Until then, add the container in Unraid with **Docker**, **Add Container**, and a template URL of:

```text
https://raw.githubusercontent.com/suchamoneypit/WARNO-Dedicated-Server-Unraid/main/templates/warno-dedicated-server.xml
```

The image is `ghcr.io/suchamoneypit/warno-unraid:latest`. It does not exist until the GitHub Action has built it. See [Publishing the image](#publishing-the-image).

Fill in:

| Field | What to enter |
| --- | --- |
| Eugen Login | The EugNet email you sent Eugen when you requested the key |
| Eugen Dedicated Key | The key Eugen emailed back |
| Public WAN IP | The address Eugen's lobby should advertise to players |
| Game Port | `10400`, or another free port |
| Server Name | The name in the server browser |
| Map | A scenario ID. The preset is `RDPort_JungleLaw_2v2_CONQ` |

Advanced fields are already set for a 2v2 Conquest match on the Red Dragon map pack: 4 players, 2 per team, combat rule `2`, mod `3811913066/0`.

### Map

**Map** is a scenario ID. Base-game IDs are the ones in Eugen's map table, such as `_2x2_Hesse_2vs2_CONQ`. Those maps are part of the dedicated server's own game data. For a base-game map, clear **Workshop Mod List**.

A workshop map uses the scenario ID stored in the mod, not the name on the workshop page. The preset keeps workshop item `3811913066` in **Workshop Mod List** and sets **Map** to `RDPort_JungleLaw_2v2_CONQ`. `Jungle Law` and `YOUR_*` placeholders are rejected.

The Red Dragon map pack scenario IDs, taken from the mod files for workshop item `3811913066`, are:

| Map | Scenario ID | Size |
| --- | --- | --- |
| 38th Parallel | `RDPort_38thParallel_4v4_CONQ` | 4v4 |
| 38th Perpendicular | `RDPort_38thPerpendicular_3v3_CONQ` | 3v3 |
| Another D-Day | `RDPort_AnotherDDay_2v2_CONQ` | 2v2 |
| Apocalypse Imminent | `RDPort_ApocalypseImminent_2v2_CONQ` | 2v2 |
| Asgard | `RDPort_Asgard_10v10_CONQ` | 10v10 |
| Back to Inchon | `RDPort_BackToInchon_3v3_CONQ` | 3v3 |
| Chosin Reservoir | `RDPort_ChosinReservoir_2v2_CONQ` | 2v2 |
| Floods | `RDPort_Floods_4v4_CONQ` | 4v4 |
| Gunboat Diplomacy | `RDPort_GunboatDiplomacy_2v2_CONQ` | 2v2 |
| Hop and Glory | `RDPort_HopAndGlory_2v2_CONQ` | 2v2 |
| Jungle Law | `RDPort_JungleLaw_2v2_CONQ` | 2v2 |
| Mud Fight | `RDPort_MudFight_1v1_CONQ` | 1v1 |
| Operation Chromite | `RDPort_OperationChromite_2v2_CONQ` | 2v2 |
| Paddy Field | `RDPort_PaddyField_2v2_CONQ` | 2v2 |
| Strait to the Point | `RDPort_StraitToThePoint_3v3_CONQ` | 3v3 |
| Sun of Juche | `RDPort_SunOfJuche_4v4_CONQ` | 4v4 |
| Tropic Thunder | `RDPort_TropicThunder_1v1_CONQ` | 1v1 |
| Wonsan Native | `RDPort_WonsanNative_2v2_CONQ` | 2v2 |

All of these are Conquest, so leave **Combat Rule** at `2`. Change **Max Players** and **Team Size** to match the map size. A 4v4 map needs 8 max players and a team size of 4. Asgard needs 20 and 10.

Eugen's [variables.ini](https://hub.docker.com/r/eugensystems/warno) page says `ModList` makes a joining player who is missing the mod get prompted to download and enable it. This container does not download workshop files itself. It writes `Map` and `ModList`, then starts Eugen's entrypoint. That entrypoint only launches `warno-server`. Whether the server binary then downloads workshop item `3811913066` has not been confirmed on a running server.

### A second server

Add another container from this same template. Change three values:

- container name
- game port
- settings folder, for example `/mnt/user/appdata/warno2/settings`

Use the same Eugen login and key. Do not use Unraid's reinstall action for this. Reinstall replaces the container you already have. Eugen refuses a sixth server on the same key.

## Settings files

On each start, **Write Config From Form** (`true`) rewrites these files in the settings folder:

- `login.ini`
- `variables.ini`
- `params_for_ai.json`

`samples/` shows the shape of those files with placeholders only. Do not replace the placeholders in this repository.

The faction matchup is NATO vs PACT (`GameType = 0`). Teams must stay the same size (`DeltaMaxTeamSize = 0`). AI decks are empty. RCON is not configured.

Set **Write Config From Form** to `false` only when you need to edit those files by hand. While it is `true`, the next start overwrites hand edits. `admins.ini` and `banned_clients.ini` created by the server are left alone.

## Keys

The dedicated key belongs in the Unraid form, which stores it for that container and writes `login.ini` on the server. It does not belong in this git repository, in an example file, or in a GitHub issue. If a key is ever committed, treat it as compromised even after a later delete, because git history keeps it. `.gitignore` ignores `login.ini` and a local `settings/` directory.

## Updates

Eugen publishes game updates as `eugensystems/warno:latest`. This repo does not copy their server launch arguments. `entrypoint-unraid.sh` writes the settings files and then runs `/server/entrypoint2.sh` from their image.

`.github/workflows/rebuild-image.yml` checks Eugen's image once a day, and also runs when the Dockerfile or entrypoint changes. If the digest changed, it builds `ghcr.io/suchamoneypit/warno-unraid:latest`. In Unraid, update each server container. A failed Action leaves the previous image in place. Fix the Action and run it again. Players on a new WARNO patch need that rebuild before the dedicated server will match the client.

Change the entrypoint only if Eugen renames `entrypoint2.sh` or the settings filenames. A normal game patch does not require an edit here.

## Publishing the image

After these files are on `main`:

1. In the GitHub repository settings, enable Issues.
2. Under Actions, allow GitHub Actions, and set workflow permissions to read and write.
3. Run the **Rebuild WARNO image** workflow.
4. Open the package `warno-unraid` and set its visibility to Public. Unraid cannot pull a private package. The workflow tries to do this, and the package page is the place to confirm it.

Then install the template on your Unraid server and confirm the container stays up, the settings files contain your key only on that server, and Jungle Law is the running scenario. Submit the repository to Community Apps after that test. The submission site is [https://ca.unraid.net/submit](https://ca.unraid.net/submit).

## Support

Questions and problems go to [GitHub issues](https://github.com/suchamoneypit/WARNO-Dedicated-Server-Unraid/issues). Leave the Eugen key out of the issue.
