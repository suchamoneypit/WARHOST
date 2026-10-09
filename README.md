# WARHOST — WARNO Dedicated Server for Unraid

WARNO was a game made in France, but WARHOST was created in the United States.

A mod-friendly WARNO dedicated server manager for Unraid. One [WARNO](https://store.steampowered.com/app/1611600/WARNO/) dedicated server per container. The install form takes your Eugen login and dedicated key and writes `login.ini`, `variables.ini`, and `params_for_ai.json`. The container then runs the entrypoint from the official `eugensystems/warno` image.

The preset is a 2v2 Conquest server for Jungle Law in the [Red Dragon map pack](https://steamcommunity.com/sharedfiles/filedetails/?id=3811913066) (Steam Workshop item `3811913066`).

First install? Follow [docs/INSTALL-UNRAID.md](docs/INSTALL-UNRAID.md). It covers the Eugen key request, router setup, the Unraid 7 install route, every field, how to confirm the server works, and troubleshooting. This README is the reference.

## What you need

- A dedicated-server **login and key** from Eugen. Email `eugsupport@eugensystems.com` with the email address of your EugNet account politely requesting a dedicated servery key; Eugen replies with a login and key pair ([Docker Hub](https://hub.docker.com/r/eugensystems/warno)). A dedicated key from another Eugen game also works. One pair can run up to five servers.
- Your **public WAN IP**, and the game port forwarded on your router **as both TCP and UDP** to the Unraid server. Eugen recommends host networking and this container uses it, so Unraid shows no Docker port mapping.
- Outbound internet from the Unraid server, so the game server can reach Eugen's master server (no offline LAN play).


## Install

Community Applications listing comes after this template has been tested on a running server. Until then, Unraid 7 has no field for a template URL (Unraid 6.10 removed it), so copy the template to the flash drive and pick it from the **Template** dropdown.

In a checkout of this repository, `sh scripts/print_template_fetch.sh` prints the command in step 1. In Cursor, `/unraid-template-installscript` runs that script and shows the same output. Paste it; the URL and the flash filename both come from the template. The download URL uses the repository name `WARHOST` and the template file on `main`.

1. Unraid web UI → terminal icon (`>_`):

   ```sh
   mkdir -p /boot/config/plugins/dockerMan/templates-user
   curl -fsSL -o /boot/config/plugins/dockerMan/templates-user/my-WARHOST.xml \
     https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/templates/warhost.xml
   ```

2. **Docker → Add Container → Template → User templates**, choose **WARHOST**, fill in the fields below, **Apply**.

The dropdown label is the flash filename with `my-` removed, so `my-WARHOST.xml` shows **WARHOST**. On Apply, Unraid writes `/boot/config/plugins/dockerMan/templates-user/my-<Name>.xml` from the Name on the form. With Name left as `WARHOST`, that is this download. A different Name leaves this file in the dropdown as a second entry, still labeled **WARHOST**. Delete an earlier download if it is still in that folder: `warno-dedicated-server.xml` or `my-WARNO-Dedicated-Server.xml`. This route is the one the Community Applications author gives for Unraid 6.10 and later. `my-WARHOST.xml` has not been tried on a server yet. `sh scripts/print_template_fetch.sh --private` saves `warhost.xml` under `/boot/config/plugins/community.applications/private/suchamoneypit/`. The full command is in the install guide.

The template installs `ghcr.io/suchamoneypit/warhost:latest`. That tag is published when **Rebuild WARHOST image** runs on `main`. The pull check is in the install guide, step 2. The settings folder stays `/mnt/user/appdata/warno/settings`. Extra search terms are `WARNO WARNO server dedicated server game server mods modded`.

Fill in:

| Field | What to enter |
| --- | --- |
| Eugen Login | The login from Eugen's reply, exactly as written, not your Steam name. This login and the key are a matching pair good for five containers. |
| Eugen Dedicated Key | The key from the same reply. Shown in clear text on this form so servers can be told apart. |
| Public WAN IP | The address Eugen's lobby should advertise to players. Look it up at <https://www.whatismyip.com/> from a device on that network if you do not know it. |
| Game Port | `10400`, or another free port. Forward the same number to this Unraid server as TCP and UDP. |
| Server Name | `WARHOST - Red Dragon 4v4`, the name in the server browser |
| Max Players | `4` for this 2v2 preset. Usual sizes are under Map. The lobby is not locked to the size in the scenario ID. |
| Minimum Players | `2`, and not above Max Players |
| Team Size | `2` for this 2v2 preset. Slots on one side, usually half of Max Players. |
| Combat Rule | `2` for Conquest, `1` for Destruction |

**Show more settings** holds Write Config From Form, Workshop Mod Tags, Workshop Mod List, and Map. Workshop Mod Tags are browser icons only and do not download mods. The preset is Jungle Law: Map `RDPort_JungleLaw_2v2_CONQ`, mod `3811913066/15`. That version is `Version` in the mod's `Config.ini` as read on 2026-10-09. If the author increments `Version`, change **Workshop Mod List** to match. Scenario IDs and named mods are in the tables below.

### Map

**Map** is a scenario ID. Base-game IDs are Eugen's Map Base Id column, read from the Docker Hub map table on 2026-10-09. They start with `_`. Those maps are part of the dedicated server's own game data, so clear **Workshop Mod List** for them. A workshop map uses the scenario ID stored in the mod, not the name on the workshop page. The preset keeps workshop item `3811913066` in **Workshop Mod List** and sets **Map** to `RDPort_JungleLaw_2v2_CONQ`. `Jungle Law` and `YOUR_*` placeholders are rejected.

The size in the scenario ID is the usual lobby, not a lock. Eugen's [variables.ini](https://hub.docker.com/r/eugensystems/warno) page does not tie player count to that size. A 1v1 ID usually uses Max Players 2 and Team Size 1, a 2v2 uses 4 and 2, a 3v3 uses 6 and 3, a 4v4 uses 8 and 4, and a 10v10 uses 20 and 10. Setting Max Players to 8 on a 2v2 map has not been tested. Combat Rule is `2` when the ID contains `CONQ`, and `1` when it contains `DEST`.

#### Base game

| Map | Scenario ID | Size |
| --- | --- | --- |
| Airport (duel) | `_3x3_Airport_1vs1_CONQ_DUEL` | 1v1 Conquest |
| Black Forest Storm (duel) | `_2x3_BlackForestStorm_1vs1_CONQ_DUEL` | 1v1 Conquest |
| Chemical (duel) | `_4x2_Chemical_1vs1_CONQ_DUEL` | 1v1 Conquest |
| Death Row (training) | `_2x3_Death_Row_1vs1_CONQ_TRAINING` | 1v1 Conquest |
| Geisa (training) | `_4x3_geisa_1vs1_CONQ_TRAINING` | 1v1 Conquest |
| Hesse (duel) | `_2x2_Hesse_1vs1_CONQ_DUEL` | 1v1 Conquest |
| Kreide (duel) | `_3x3_Kreide_1vs1_CONQ_DUEL` | 1v1 Conquest |
| Mount River (duel) | `_3x3_MountRiver_1vs1_CONQ_DUEL` | 1v1 Conquest |
| Mount River (training) | `_3x3_MountRiver_1vs1_CONQ_TRAINING` | 1v1 Conquest |
| Ohmen (duel) | `_2x3_Ohmen_1vs1_CONQ_DUEL` | 1v1 Conquest |
| Two Lakes (duel) | `_2x3_Two_lakes_1vs1_CONQ_DUEL` | 1v1 Conquest |
| Urban Frontlines (duel) | `_3x3_UrbanFrontlines_1vs1_CONQ_DUEL` | 1v1 Conquest |
| Vertigo (duel) | `_2x3_Vertigo_1vs1_CONQ_DUEL` | 1v1 Conquest |
| Albion Military Base | `_2x3_Albion_Military_Base_2vs2_CONQ` | 2v2 Conquest |
| Black Forest Storm | `_2x3_BlackForestStorm_2vs2_CONQ` | 2v2 Conquest |
| Chemical (training) | `_4x2_Chemical_2vs2_CONQ_TRAINING` | 2v2 Conquest |
| Death Row | `_2x3_Death_Row_2vs2_CONQ` | 2v2 Conquest |
| Hesse | `_2x2_Hesse_2vs2_CONQ` | 2v2 Conquest |
| Loop | `_5x2_Loop_2vs2_CONQ` | 2v2 Conquest |
| Mount River (assault) | `_3x3_MountRiver_2vs2_CONQ_ASSAULT` | 2v2 Conquest |
| Ripple | `_2x3_Ripple_2vs2_CONQ` | 2v2 Conquest |
| Tension | `_2x2_Tension_2vs2_CONQ` | 2v2 Conquest |
| Teufelsmoor | `_2x2_Teufelsmoor_2vs2_CONQ` | 2v2 Conquest |
| Two Lakes | `_2x3_Two_lakes_2vs2_CONQ` | 2v2 Conquest |
| Two Ways | `_2x3_TwoWays_2vs2_CONQ` | 2v2 Conquest |
| Urban Frontlines | `_3x3_UrbanFrontlines_2vs2_CONQ` | 2v2 Conquest |
| Vertigo | `_2x3_Vertigo_2vs2_CONQ` | 2v2 Conquest |
| Death Row | `_2x3_Death_Row_2vs2_DEST` | 2v2 Destruction |
| Ripple | `_2x3_Ripple_2vs2_DEST` | 2v2 Destruction |
| Two Lakes | `_2x3_Two_lakes_2vs2_DEST` | 2v2 Destruction |
| Two Ways | `_2x3_TwoWays_2vs2_DEST` | 2v2 Destruction |
| Vertigo | `_2x3_Vertigo_2vs2_DEST` | 2v2 Destruction |
| Airport | `_3x3_Airport_3vs3_CONQ` | 3v3 Conquest |
| Cliff | `_4x3_Cliff_3vs3_CONQ` | 3v3 Conquest |
| Cyrus | `_3x3_Cyrus_3vs3_CONQ` | 3v3 Conquest |
| Danger Hills | `_3x3_DangerHills_3vs3_CONQ` | 3v3 Conquest |
| Eiche | `_3x3_Eiche_3vs3_CONQ` | 3v3 Conquest |
| Factory | `_3x3_Factory_3vs3_CONQ` | 3v3 Conquest |
| Kreide | `_3x3_Kreide_3vs3_CONQ` | 3v3 Conquest |
| Mount River | `_3x3_MountRiver_3vs3_CONQ` | 3v3 Conquest |
| Railway | `_3x3_Railway_3vs3_CONQ` | 3v3 Conquest |
| Rift | `_3x3_Rift_3vs3_CONQ` | 3v3 Conquest |
| Rocks | `_3x3_Rocks_3vs3_CONQ` | 3v3 Conquest |
| Rocks (assault) | `_3x3_Rocks_3vs3_CONQ_ASSAULT` | 3v3 Conquest |
| Stoneware | `_3x3_Stoneware_3vs3_CONQ` | 3v3 Conquest |
| Surrounded | `_3x3_Surrounded_3vs3_CONQ` | 3v3 Conquest |
| Triple Strike | `_3x3_TripleStrike_3vs3_CONQ` | 3v3 Conquest |
| Twin Cities | `_3x3_TwinCities_3vs3_CONQ` | 3v3 Conquest |
| Two Ways | `_2x3_TwoWays_3vs3_CONQ` | 3v3 Conquest |
| Urban Frontlines | `_3x3_UrbanFrontlines_3vs3_CONQ` | 3v3 Conquest |
| Valley | `_3x3_Valley_3vs3_CONQ` | 3v3 Conquest |
| Volcano | `_3x3_Volcano_3vs3_CONQ` | 3v3 Conquest |
| Airport | `_3x3_Airport_3vs3_DEST` | 3v3 Destruction |
| Cyrus | `_3x3_Cyrus_3vs3_DEST` | 3v3 Destruction |
| Danger Hills | `_3x3_DangerHills_3vs3_DEST` | 3v3 Destruction |
| Eiche | `_3x3_Eiche_3vs3_DEST` | 3v3 Destruction |
| Factory | `_3x3_Factory_3vs3_DEST` | 3v3 Destruction |
| Kreide | `_3x3_Kreide_3vs3_DEST` | 3v3 Destruction |
| Mount River | `_3x3_MountRiver_3vs3_DEST` | 3v3 Destruction |
| Railway | `_3x3_Railway_3vs3_DEST` | 3v3 Destruction |
| Rift | `_3x3_Rift_3vs3_DEST` | 3v3 Destruction |
| Rocks | `_3x3_Rocks_3vs3_DEST` | 3v3 Destruction |
| Stoneware | `_3x3_Stoneware_3vs3_DEST` | 3v3 Destruction |
| Surrounded | `_3x3_Surrounded_3vs3_DEST` | 3v3 Destruction |
| Triple Strike | `_3x3_TripleStrike_3vs3_DEST` | 3v3 Destruction |
| Twin Cities | `_3x3_TwinCities_3vs3_DEST` | 3v3 Destruction |
| Urban Frontlines | `_3x3_UrbanFrontlines_3vs3_DEST` | 3v3 Destruction |
| Valley | `_3x3_Valley_3vs3_DEST` | 3v3 Destruction |
| Volcano | `_3x3_Volcano_3vs3_DEST` | 3v3 Destruction |
| Chemical | `_4x2_Chemical_4vs4_CONQ` | 4v4 Conquest |
| Dark Stream | `_4x2_DarkStream_4vs4_CONQ` | 4v4 Conquest |
| Chemical | `_4x2_Chemical_4vs4_DEST` | 4v4 Destruction |
| Airport | `_3x3_Airport_10vs10_CONQ` | 10v10 Conquest |
| Crown | `_5x2_crown_10vs10_CONQ` | 10v10 Conquest |
| Cyrus | `_3x3_Cyrus_10vs10_CONQ` | 10v10 Conquest |
| Danger Hills | `_3x3_DangerHills_10vs10_CONQ` | 10v10 Conquest |
| Dark Stream | `_4x2_DarkStream_10vs10_CONQ` | 10v10 Conquest |
| Factory | `_3x3_Factory_10vs10_CONQ` | 10v10 Conquest |
| Geisa | `_4x3_geisa_10vs10_CONQ` | 10v10 Conquest |
| Iron Waters | `_3x3_IronWaters_10vs10_CONQ` | 10v10 Conquest |
| Kreide | `_3x3_Kreide_10vs10_CONQ` | 10v10 Conquest |
| Loop | `_5x2_Loop_10vs10_CONQ` | 10v10 Conquest |
| Railway | `_3x3_Railway_10vs10_CONQ` | 10v10 Conquest |
| Rift | `_3x3_Rift_10vs10_CONQ` | 10v10 Conquest |
| Rocks | `_3x3_Rocks_10vs10_CONQ` | 10v10 Conquest |
| Stoneware | `_3x3_Stoneware_10vs10_CONQ` | 10v10 Conquest |
| Surrounded | `_3x3_Surrounded_10vs10_CONQ` | 10v10 Conquest |
| Triple Strike | `_3x3_TripleStrike_10vs10_CONQ` | 10v10 Conquest |
| Twin Cities | `_3x3_TwinCities_10vs10_CONQ` | 10v10 Conquest |
| Urban Frontlines | `_3x3_UrbanFrontlines_10vs10_CONQ` | 10v10 Conquest |
| Valley | `_3x3_Valley_10vs10_CONQ` | 10v10 Conquest |
| Volcano | `_3x3_Volcano_10vs10_CONQ` | 10v10 Conquest |
| Airport | `_3x3_Airport_10vs10_DEST` | 10v10 Destruction |
| Crown | `_5x2_crown_10vs10_DEST` | 10v10 Destruction |
| Cyrus | `_3x3_Cyrus_10vs10_DEST` | 10v10 Destruction |
| Danger Hills | `_3x3_DangerHills_10vs10_DEST` | 10v10 Destruction |
| Geisa | `_4x3_geisa_10vs10_DEST` | 10v10 Destruction |
| Iron Waters | `_3x3_IronWaters_10vs10_DEST` | 10v10 Destruction |
| Kreide | `_3x3_Kreide_10vs10_DEST` | 10v10 Destruction |
| Loop | `_5x2_Loop_10vs10_DEST` | 10v10 Destruction |
| Rocks | `_3x3_Rocks_10vs10_DEST` | 10v10 Destruction |
| Volcano | `_3x3_Volcano_10vs10_DEST` | 10v10 Destruction |

#### Red Dragon map pack

The Red Dragon scenario IDs are the file names in the mod's `Scenarios/` folder on a PC subscribed to item `3811913066` (`steamapps/workshop/content/1611600/3811913066/Scenarios/`, each ID appearing as `<ID>_Definition.dat` and three sibling files). The list below was read from those files on 2026-10-09. The procedure is in the install guide, step 4. The Workshop page says Wonsan Harbour; the file name is `WonsanNative`.

| Map | Scenario ID | Size |
| --- | --- | --- |
| Mud Fight | `RDPort_MudFight_1v1_CONQ` | 1v1 |
| Tropic Thunder | `RDPort_TropicThunder_1v1_CONQ` | 1v1 |
| Another D-Day | `RDPort_AnotherDDay_2v2_CONQ` | 2v2 |
| Apocalypse Imminent | `RDPort_ApocalypseImminent_2v2_CONQ` | 2v2 |
| Chosin Reservoir | `RDPort_ChosinReservoir_2v2_CONQ` | 2v2 |
| Gunboat Diplomacy | `RDPort_GunboatDiplomacy_2v2_CONQ` | 2v2 |
| Hop and Glory | `RDPort_HopAndGlory_2v2_CONQ` | 2v2 |
| Jungle Law | `RDPort_JungleLaw_2v2_CONQ` | 2v2 |
| Operation Chromite | `RDPort_OperationChromite_2v2_CONQ` | 2v2 |
| Paddy Field | `RDPort_PaddyField_2v2_CONQ` | 2v2 |
| Wonsan Harbour (file name `WonsanNative`) | `RDPort_WonsanNative_2v2_CONQ` | 2v2 |
| 38th Perpendicular | `RDPort_38thPerpendicular_3v3_CONQ` | 3v3 |
| Back to Inchon | `RDPort_BackToInchon_3v3_CONQ` | 3v3 |
| Strait to the Point | `RDPort_StraitToThePoint_3v3_CONQ` | 3v3 |
| 38th Parallel | `RDPort_38thParallel_4v4_CONQ` | 4v4 |
| Floods | `RDPort_Floods_4v4_CONQ` | 4v4 |
| Sun of Juche | `RDPort_SunOfJuche_4v4_CONQ` | 4v4 |
| Asgard | `RDPort_Asgard_10v10_CONQ` | 10v10 |

Every map in that table is Conquest, so leave **Combat Rule** at `2` for them.

#### Workshop mods

| Mod | Workshop id | Workshop Mod List | Workshop Mod Tags |
| --- | --- | --- | --- |
| [Galactic Divide](https://steamcommunity.com/sharedfiles/filedetails/?id=3595948209) | `3595948209` | Read `Version` in `Config.ini`. The page does not publish it. | `Gameplay-Interface-Sound-Scenarios-Maps` |
| [A World in Flames](https://steamcommunity.com/sharedfiles/filedetails/?id=3388575848) | `3388575848` | Read `Version` in `Config.ini`. The page does not publish it. | `Gameplay-Interface`, or `Gameplay-Interface-Maps-Scenarios` with a map pack |
| [WARNO: Red Dragon - Map Pack](https://steamcommunity.com/sharedfiles/filedetails/?id=3811913066) | `3811913066` | `3811913066/15` | `Maps-Scenarios` |
| [WEST FULDA 1.0](https://steamcommunity.com/sharedfiles/filedetails/?id=3363584349) | `3363584349` | Read `Version` in `Config.ini`. The page does not publish it. | `Maps-Scenarios` |
| [Highway to Oslo](https://steamcommunity.com/sharedfiles/filedetails/?id=3474588989) | `3474588989` | Read `Version` in `Config.ini`. The page does not publish it. | `Maps-Scenarios` |
| [Ramstein Air Base](https://steamcommunity.com/sharedfiles/filedetails/?id=3705706772) | `3705706772` | Read `Version` in `Config.ini`. The page does not publish it. | `Maps-Scenarios` |
| [Arsenal](https://steamcommunity.com/sharedfiles/filedetails/?id=3415339374) | `3415339374` | Read `Version` in `Config.ini`. The page does not publish it. | `Maps-Scenarios` |
| [Helbe](https://steamcommunity.com/sharedfiles/filedetails/?id=3762638679) | `3762638679` | Read `Version` in `Config.ini`. The page does not publish it. | `Maps-Scenarios` |

Galactic Divide and A World in Flames, read on 2026-10-09, are a total conversion and a modern-day overhaul. They are not maps, so **Map** stays a scenario ID. Join a conversion and a map pack with a hyphen only after each `Version` comes from that mod's `Config.ini`.

The five map packs do not publish scenario IDs. After you subscribe, use the filename before `_Definition.dat` as **Map**. WEST FULDA 1.0, Highway to Oslo, Ramstein Air Base, and Arsenal list both Conquest and Destruction. Helbe's page lists Conquest only.

| Pack | What the Workshop page lists |
| --- | --- |
| WEST FULDA 1.0 | A full map at 4v4 and 10v10, Neuenberg 2v2, Kammerzell 1v1 and 2v2, Grossenluder 1v1, Bimbach 2v2, Malkes 3v3, in Conquest and Destruction, plus 9 Army General maps |
| Highway to Oslo | 1v1 Conquest, 1v1 Destruction, and the same two with no sidespawn |
| Ramstein Air Base | 3v3 Conquest and 3v3 Destruction |
| Arsenal | 2v2 and 3v3, each in Conquest and Destruction |
| Helbe | Conquest only: a full map at 4v4 and 10v10, ZENTRUM 3v3 and 10v10, WIDE 4v4 and 10v10, STREAM 2v2, 3v3, and 10v10, NORDEN 3v3, HOCHLAND 2v2, and SUDEN DUEL 1v1 |

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

Set **Write Config From Form** to `false` only when you need to edit those files by hand. While it is `true`, the next start overwrites hand edits. Any other file the server itself creates in that folder (for example `admins.ini` or `banned_clients.ini`, if it creates them) is left alone.

## Keys

Login from Eugen's reply, exactly as written. Not your Steam name; this login and the key are a matching pair good for five containers.

The dedicated key belongs in the Unraid form, which stores it for that container and writes `login.ini` on the server. The form shows the key in clear text so servers can be told apart. The startup log names only the last 4 characters. A key shorter than 4 characters stops the start with `Eugen dedicated key must be at least 4 characters.` The key does not belong in this git repository, in an example file, or in a GitHub issue. If a key is ever committed, treat it as compromised even after a later delete, because git history keeps it. `.gitignore` ignores `login.ini` and a local `settings/` directory.

## Updates

Eugen publishes game updates as `eugensystems/warno:latest`. This repo does not copy their server launch arguments. `entrypoint-unraid.sh` writes the settings files and then runs `/server/entrypoint2.sh` from their image.

`.github/workflows/rebuild-image.yml` checks Eugen's image once a day, and also runs when the Dockerfile or entrypoint changes. If the digest changed, it builds `ghcr.io/suchamoneypit/warhost:latest`. In Unraid, update each server container. A failed Action leaves the previous image in place. Fix the Action and run it again. Players on a new WARNO patch need that rebuild before the dedicated server will match the client.

Change the entrypoint only if Eugen renames `entrypoint2.sh` or the settings filenames. A normal game patch does not require an edit here.

## Publishing the image (maintainers)

The image is already published. If you fork this repository, repeat these steps once your files are on `main`:

1. In the GitHub repository settings, enable Issues.
2. Under Actions, allow GitHub Actions, and set workflow permissions to read and write.
3. Run the **Rebuild WARHOST image** workflow.
4. Open the package `warhost` and set its visibility to Public. Unraid cannot pull a private package. The workflow tries to do this for `warhost`, and the package page is the place to confirm it.

Then install the template on your Unraid server and confirm the container stays up, the settings files contain your key only on that server, and Jungle Law is the running scenario. Submit the repository to Community Apps after that test. The submission site is [https://ca.unraid.net/submit](https://ca.unraid.net/submit).

## Documentation

| File | Contents |
| --- | --- |
| [docs/INSTALL-UNRAID.md](docs/INSTALL-UNRAID.md) | First install, step by step, with verification and troubleshooting |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | What the repository contains and what was verified, with sources |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Why things are the way they are |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Goals and known issues |
| [docs/UNRAID-TEMPLATE-GUIDE.md](docs/UNRAID-TEMPLATE-GUIDE.md) | Generic Unraid template guidance, reusable for other game servers |
| [docs/CURSOR-QUICKSTART.md](docs/CURSOR-QUICKSTART.md) | Working on this repository with Cursor's agents |

## Made with AI tools

This project was built with AI coding assistants (mainly [Cursor](https://cursor.com)). Humans directed the work, reviewed what shipped, and remain responsible for it. Treat the template like any other community Docker or Unraid project: verify on your own server, and open an issue if something is wrong. Notes for working on the Cursor setup in this repository are in [docs/CURSOR-QUICKSTART.md](docs/CURSOR-QUICKSTART.md).

## Support

Questions and problems go to [GitHub issues](https://github.com/suchamoneypit/WARHOST/issues). Leave the Eugen key out of the issue.
