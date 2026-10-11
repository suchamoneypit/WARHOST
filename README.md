# WARHOST — WARNO Dedicated Server for Unraid

A mod-friendly, multi-instance capable WARNO dedicated server manager for Unraid. One [WARNO](https://store.steampowered.com/app/1611600/WARNO/) dedicated server per container. The install form takes your Eugen login and dedicated key (provided by Eugen upon request) and writes `login.ini`, `variables.ini`, and `params_for_ai.json`. The container then runs the entrypoint from the official `eugensystems/warno` image.

The preset is a 2v2 Conquest server on the base-game map Hesse (`_2x2_Hesse_2vs2_CONQ`) with no workshop mods, so players need only the game. To host the [Red Dragon map pack](https://steamcommunity.com/sharedfiles/filedetails/?id=3811913066) (Steam Workshop item `3811913066`) instead, set Workshop Mod List to `3811913066` and choose a scenario ID from the [scenario lists](#scenario-ids). Each start reads that mod's current `Version` from Steam, so after the author publishes an update, restart the container.

If you've used other game servers before you likely can toll the unraid template tooltips only, and setup your standard port forward and you are done. Looking for more info? Follow [docs/INSTALL-UNRAID.md](docs/INSTALL-UNRAID.md). It covers the Eugen key request, router setup, the Unraid 7 install route, every field, how to confirm the server works, and troubleshooting. This README is the reference.

## What you need

- A dedicated-server **login and key** from Eugen. Email `eugsupport@eugensystems.com` with the email address of your EugNet account politely requesting a dedicated servery key; Eugen replies with a login and key pair ([Docker Hub](https://hub.docker.com/r/eugensystems/warno)). A dedicated key from another Eugen game also works. One pair can run up to five servers.
- Your **public WAN IP**, and the game port forwarded on your router **as both TCP and UDP** to the Unraid server. Eugen recommends host networking and this container uses it, so Unraid shows no Docker port mapping.
- Outbound internet from the Unraid server, so the game server can reach Eugen's master server (no offline LAN play), and so each start can read a Workshop mod's `Version` from Steam.


## Install

Community Applications listing comes after this template has been tested on a running server. Until then, Unraid 7 has no field for a template URL (Unraid 6.10 removed it), so copy the template to the flash drive and pick it from the **Template** dropdown. APPROVED, PENDING PUBLISH AS OF 10/9/26

In a checkout of this repository, `sh scripts/print_template_fetch.sh` prints the command in step 1. In Cursor, `/unraid-script` prints that command for `main`, a separate command for `dev` (`my-WARHOST-dev.xml`), a separate command for `webui` (`my-WARHOST-webui.xml`), and a clean-slate command. Paste only the branch you are about to add. The download URL uses the repository name `WARHOST` and the template file on that branch. Applying a branch template still writes `my-WARHOST.xml`, because `<Name>` on each branch is `WARHOST`, and leaves the suffixed file in the dropdown. The clean-slate command removes the `WARHOST`, `WARHOST-dev`, and `WARHOST-webui` containers and those template files. It also drops those names from `/var/lib/docker/unraid-autostart` and deletes the three private files under `/boot/config/plugins/community.applications/private/suchamoneypit/`. It removes `ghcr.io/suchamoneypit/warhost:latest` only when no container is still using it. It also removes `/mnt/user/appdata/warno/<port>/settings` for those containers, which holds the login and key. A folder still mounted by another container is left in place.

1. Unraid web UI → terminal icon (`>_`):

   ```sh
   mkdir -p /boot/config/plugins/dockerMan/templates-user
   curl -fsSL -o /boot/config/plugins/dockerMan/templates-user/my-WARHOST.xml \
     https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/templates/warhost.xml
   ```

2. **Docker → Add Container → Template → User templates**, choose **WARHOST**, fill in the fields below, **Apply**.

The dropdown label is the flash filename with `my-` removed, so `my-WARHOST.xml` shows **WARHOST**. On Apply, Unraid writes `/boot/config/plugins/dockerMan/templates-user/my-<Name>.xml` from the Name on the form. With Name left as `WARHOST`, that is this download. A different Name leaves this file in the dropdown as a second entry, still labeled **WARHOST**. Delete an earlier download if it is still in that folder: `warno-dedicated-server.xml` or `my-WARNO-Dedicated-Server.xml`. This route is the one the Community Applications author gives for Unraid 6.10 and later. On 2026-10-09 Unraid 7.3.3 showed `my-WARHOST.xml` in that dropdown as **WARHOST**. The install guide records what that try did and did not prove. `sh scripts/print_template_fetch.sh --private` saves `warhost.xml` under `/boot/config/plugins/community.applications/private/suchamoneypit/`. The full command is in the install guide.

The template installs `ghcr.io/suchamoneypit/warhost:latest`. That tag is published when **Rebuild WARHOST image** runs on `main`. The pull check is in the install guide, step 2. The first server's settings folder is `/mnt/user/appdata/warno/10400/settings`. Every container shares that one image. Extra search terms are `WARNO WARNO server dedicated server game server mods modded`.

Fill in:

<table>
<thead>
<tr>
<th align="left" nowrap>Field</th>
<th align="left">What to enter</th>
</tr>
</thead>
<tbody>
<tr>
<td nowrap>Eugen Login</td>
<td>The login from Eugen's reply, exactly as written, not your Steam name. This login and the key are a matching pair good for five containers.</td>
</tr>
<tr>
<td nowrap>Eugen Dedicated Key</td>
<td>The key from the same reply. Shown in clear text on this form so servers can be told apart.</td>
</tr>
<tr>
<td nowrap>Public WAN IP</td>
<td>The address Eugen's lobby should advertise to players. Look it up at <a href="https://www.whatismyip.com/">https://www.whatismyip.com/</a> from a device on that network if you do not know it.</td>
</tr>
<tr>
<td nowrap>Settings Folder</td>
<td><code>/mnt/user/appdata/warno/10400/settings</code> for the first server. The next container uses this path with the port number plus 1, for example <code>/mnt/user/appdata/warno/10401/settings</code>. The folder holds the ini files only.</td>
</tr>
<tr>
<td nowrap>Game Port</td>
<td><code>10400</code> for the first server. The next container uses that number plus 1. Forward each number to this Unraid server as TCP and UDP. Players join by Server Name.</td>
</tr>
<tr>
<td nowrap>Server Name</td>
<td><code>WARHOST - Hesse 2v2</code> on the first server. Give each container a different name. No <code>=</code> sign.</td>
</tr>
<tr>
<td nowrap>Map</td>
<td><code>_2x2_Hesse_2vs2_CONQ</code>, a base-game map that needs no mod. A scenario ID, not the display name. Base-game and workshop lists are in the tables below.</td>
</tr>
<tr>
<td nowrap>Max Players</td>
<td><code>4</code> for this 2v2 preset. Usual sizes are in the Map section below. The lobby is not locked to the size in the scenario ID.</td>
</tr>
<tr>
<td nowrap>Minimum Players</td>
<td><code>2</code>, and not above Max Players</td>
</tr>
<tr>
<td nowrap>Team Size</td>
<td><code>2</code> for this 2v2 preset. Slots on one side, usually half of Max Players.</td>
</tr>
<tr>
<td nowrap>Combat Rule</td>
<td><code>2</code> for Conquest, <code>1</code> for Destruction. The scenario lists below give the mode of each map.</td>
</tr>
<tr>
<td nowrap>Workshop Mod List (Show more settings)</td>
<td>Empty for a base-game map, which is the preset. For the Red Dragon pack, <code>3811913066</code>. Each start reads the mod's current <code>Version</code> from Steam and writes the pair, for example <code>3811913066/27</code>. Typing <code>3811913066/27</code> pins that number. <code>none</code> also means empty. Named mods are in the tables below.</td>
</tr>
<tr>
<td nowrap>Write Config From Form (Show more settings)</td>
<td><code>true</code>. Rewrites the three settings files from this form on every start. <code>false</code> leaves those files and sets <code>login.ini</code> to mode 600.</td>
</tr>
<tr>
<td nowrap>Workshop Mod Tags (Show more settings)</td>
<td>Empty for a base-game map. <code>Maps-Scenarios</code> for a map pack such as Red Dragon. Browser icons only. These tags do not download mods. <code>none</code> also means empty.</td>
</tr>
</tbody>
</table>

Map is on the main form, under Server Name and before Max Players. **Show more settings** holds Workshop Mod List, Write Config From Form, and Workshop Mod Tags, in that order. The preset is Hesse 2v2 (`_2x2_Hesse_2vs2_CONQ`) with both workshop fields empty. Scenario IDs and named mods are in the tables below.

Unraid refills a cleared field from the template default ([Helpers.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/Helpers.php)). A container added from an earlier version of this template still holds the old Red Dragon defaults, so type `none` in both workshop fields there.

### Map

**Map** takes a scenario ID from the [lists below](#scenario-ids). Base-game maps need no mod, so leave **Workshop Mod List** and **Workshop Mod Tags** empty for them. A workshop map also needs its mod in those two fields, from the [workshop mods](#workshop-mods) table. When the startup log warns about the map or the mod list, the [troubleshooting table](docs/INSTALL-UNRAID.md#troubleshooting) in the install guide says what to change.

The size in the ID is the usual lobby. Eugen's [variables.ini](https://hub.docker.com/r/eugensystems/warno) page does not tie player count to that size. The usual settings are Max Players 2 and Team Size 1 for 1v1, 4 and 2 for 2v2, 6 and 3 for 3v3, 8 and 4 for 4v4, and 20 and 10 for 10v10.

#### Workshop mods

**Workshop Mod List** loads the mod that contains the maps. Enter the Workshop id from the table; each start reads that mod's current `Version` and writes `id/version`. Pick **Map** from that mod's scenario list below. Red Dragon is the first row: Workshop Mod List `3811913066`, Workshop Mod Tags `Maps-Scenarios`, and Map `RDPort_JungleLaw_2v2_CONQ` for Jungle Law.

| Mod | Workshop Mod List | Pin as read | Workshop Mod Tags |
| --- | --- | --- | --- |
| [WARNO: Red Dragon - Map Pack](https://steamcommunity.com/sharedfiles/filedetails/?id=3811913066) | `3811913066` | `3811913066/27` | `Maps-Scenarios` |
| [WEST FULDA 1.0](https://steamcommunity.com/sharedfiles/filedetails/?id=3363584349) | `3363584349` | `3363584349/1023` | `Maps-Scenarios` |
| [Highway to Oslo](https://steamcommunity.com/sharedfiles/filedetails/?id=3474588989) | `3474588989` | `3474588989/14` | `Maps-Scenarios` |
| [Ramstein Air Base](https://steamcommunity.com/sharedfiles/filedetails/?id=3705706772) | `3705706772` | `3705706772/9` | `Maps-Scenarios` |
| [Arsenal](https://steamcommunity.com/sharedfiles/filedetails/?id=3415339374) | `3415339374` | `3415339374/20` | `Maps-Scenarios` |
| [Helbe](https://steamcommunity.com/sharedfiles/filedetails/?id=3762638679) | `3762638679` | `3762638679/36` | `Maps-Scenarios` |
| [Galactic Divide](https://steamcommunity.com/sharedfiles/filedetails/?id=3595948209) | `3595948209` | `3595948209/16` | `Gameplay-Interface-Sound-Scenarios-Maps` |
| [A World in Flames](https://steamcommunity.com/sharedfiles/filedetails/?id=3388575848) | `3388575848` | `3388575848/7` | `Gameplay-Interface`, or `Gameplay-Interface-Maps-Scenarios` with a map pack |

The pin column is each mod's `Version` from its `Config.ini`, read on 2026-10-09 (Red Dragon on 2026-10-10). A pin holds that number, so players are refused once the author increments `Version`. Enter the bare id unless you need to hold a number.

Galactic Divide is a total conversion and A World in Flames is a modern-day overhaul. Neither has scenario IDs of its own, so **Map** comes from the base game or a map pack. Join a conversion and a map pack with a hyphen, for example `3595948209-3811913066`.

Joining players subscribe to each Workshop item in the list and enable it in WARNO's Mod Center. Eugen's [variables.ini](https://hub.docker.com/r/eugensystems/warno) page says a joining player who is missing a `ModList` mod is prompted to download and enable it. To read `Version`, the container downloads just the mod's `Config.ini` from Steam with [DepotDownloader](https://github.com/SteamRE/DepotDownloader), on the first start and after each update the author publishes.

#### Scenario IDs

Map packs come first and the base game is last. Copy the value from the **Scenario ID** column into **Map**. The `SM_` names under some packs are Army General files; pick **Map** from the tables. For a mod not listed here, [step 4 of the install guide](docs/INSTALL-UNRAID.md#4-decide-the-map-and-find-a-scenario-id) shows how to find its IDs.

<details>
<summary>Red Dragon map pack (28 scenario IDs)</summary>

Workshop Mod List `3811913066`. Every map is Conquest, so **Combat Rule** stays `2`.

| Map | Scenario ID | Size |
| --- | --- | --- |
| Hell in a Very Small Place | `RDPort_HellInAVerySmallPlace_1v1_CONQ` | 1v1 |
| Mud Fight | `RDPort_MudFight_1v1_CONQ` | 1v1 |
| Paddy Field | `RDPort_PaddyField_1v1_CONQ` | 1v1 |
| Strait to the Point (file name `StraitSmall`) | `RDPort_StraitSmall_1v1_CONQ` | 1v1 |
| Tropic Thunder | `RDPort_TropicThunder_1v1_CONQ` | 1v1 |
| Wonsan Harbour Land & Sea (file name `WonsanLandSea`) | `RDPort_WonsanLandSea_1v1_CONQ` | 1v1 |
| Another D-Day | `RDPort_AnotherDDay_2v2_CONQ` | 2v2 |
| Apocalypse Imminent | `RDPort_ApocalypseImminent_2v2_CONQ` | 2v2 |
| Chosin Reservoir | `RDPort_ChosinReservoir_2v2_CONQ` | 2v2 |
| Gunboat Diplomacy | `RDPort_GunboatDiplomacy_2v2_CONQ` | 2v2 |
| Hop and Glory | `RDPort_HopAndGlory_2v2_CONQ` | 2v2 |
| Jungle Law | `RDPort_JungleLaw_2v2_CONQ` | 2v2 |
| Operation Chromite | `RDPort_OperationChromite_2v2_CONQ` | 2v2 |
| Paddy Field | `RDPort_PaddyField_2v2_CONQ` | 2v2 |
| Strait to the Point Land & Sea (file name `StraitSmallLandSea`) | `RDPort_StraitSmallLandSea_2v2_CONQ` | 2v2 |
| Wonsan Harbour (file name `WonsanNative`) | `RDPort_WonsanNative_2v2_CONQ` | 2v2 |
| 38th Perpendicular | `RDPort_38thPerpendicular_3v3_CONQ` | 3v3 |
| Another D-Day in Paradise Land & Sea | `RDPort_AnotherDDayLandSea_3v3_CONQ` | 3v3 |
| Back to Inchon | `RDPort_BackToInchon_3v3_CONQ` | 3v3 |
| Gunboat Diplomacy Land & Sea | `RDPort_GunboatLandSea_3v3_CONQ` | 3v3 |
| Strait to the Point | `RDPort_StraitToThePoint_3v3_CONQ` | 3v3 |
| 38th Parallel | `RDPort_38thParallel_4v4_CONQ` | 4v4 |
| Battle of Yuchalnok Pass | `RDPort_BattleOfYuchalnokPass_4v4_CONQ` | 4v4 |
| Final Meltdown | `RDPort_FinalMeltdown_4v4_CONQ` | 4v4 |
| Floods | `RDPort_Floods_4v4_CONQ` | 4v4 |
| Strait to the Point Land & Sea (file name `StraitLandSea`) | `RDPort_StraitLandSea_4v4_CONQ` | 4v4 |
| Sun of Juche | `RDPort_SunOfJuche_4v4_CONQ` | 4v4 |
| Asgard | `RDPort_Asgard_10v10_CONQ` | 10v10 |

</details>

<details>
<summary>WEST FULDA 1.0 (16 scenario IDs)</summary>

Workshop Mod List `3363584349`.

| Map | Scenario ID | Size |
| --- | --- | --- |
| West Fulda | `_3x3_WFulda_4v4_CONQ` | 4v4 Conquest |
| West Fulda | `_3x3_WFulda_4v4_DEST` | 4v4 Destruction |
| West Fulda | `_3x3_WFulda_10v10_CONQ` | 10v10 Conquest |
| West Fulda | `_3x3_WFulda_10v10_DEST` | 10v10 Destruction |
| Bimbach | `_3x3_WFuldaBimbach_2v2_CONQ` | 2v2 Conquest |
| Bimbach | `_3x3_WFuldaBimbach_2v2_DEST` | 2v2 Destruction |
| Grossenluder | `_3x3_WFuldaGrossen_1v1_CONQ` | 1v1 Conquest |
| Grossenluder | `_3x3_WFuldaGrossen_2v2_DEST` | 2v2 Destruction |
| Kammerzell | `_3x3_WFuldaKammerzell_1v1_CONQ` | 1v1 Conquest |
| Kammerzell | `_3x3_WFuldaKammerzell_2v2_CONQ` | 2v2 Conquest |
| Kammerzell | `_3x3_WFuldaKammerzell_2v2_DEST` | 2v2 Destruction |
| Malkes | `_3x3_WFuldaMalkes_3v3_CONQ` | 3v3 Conquest |
| Malkes | `_3x3_WFuldaMalkes_3v3_DEST` | 3v3 Destruction |
| Neuenberg | `_3x3_WFuldaNeuen_1v1_CONQ` | 1v1 Conquest |
| Neuenberg | `_3x3_WFuldaNeuen_2v2_CONQ` | 2v2 Conquest |
| Neuenberg | `_3x3_WFuldaNeuen_2v2_DEST` | 2v2 Destruction |

Army General file names:

- `SM_FO_3x3_WestFulda_01`
- `SM_FO_3x3_WestFulda_02`
- `SM_PL_3x3_WestFulda_01`
- `SM_PL_3x3_WestFulda_02`
- `SM_PL_3x3_WestFulda_03`
- `SM_PL_3x3_WestFulda_04`
- `SM_SU_3x3_WestFulda_01`
- `SM_SU_3x3_WestFulda_02`
- `SM_SU_3x3_WestFulda_03`

</details>

<details>
<summary>Highway to Oslo (4 scenario IDs)</summary>

Workshop Mod List `3474588989`. The Workshop page lists these as 1v1.

| Map | Scenario ID | Size |
| --- | --- | --- |
| Highway to Oslo | `_2x2_Oslo_Conquest` | Conquest |
| Highway to Oslo | `_2x2_Oslo_Destruction` | Destruction |
| Highway to Oslo | `_2x2_Oslo_ConquestNS` | Conquest, no sidespawn |
| Highway to Oslo | `_2x2_Oslo_DestructionNS` | Destruction, no sidespawn |

</details>

<details>
<summary>Ramstein Air Base (2 scenario IDs)</summary>

Workshop Mod List `3705706772`. The Workshop page lists these as 3v3.

| Map | Scenario ID | Size |
| --- | --- | --- |
| Ramstein Air Base | `_2x2_Ramstein_Conquest` | Conquest |
| Ramstein Air Base | `_2x2_Ramstein_Destruction` | Destruction |

</details>

<details>
<summary>Arsenal (4 scenario IDs)</summary>

Workshop Mod List `3415339374`. The Workshop page lists 2v2 and 3v3 layouts, each in Conquest and Destruction.

| Map | Scenario ID | Size |
| --- | --- | --- |
| Two Hills | `_2x3_TwoHills_Conquest` | Conquest |
| Two Hills | `_2x3_TwoHills_Destruction` | Destruction |
| Two Hills | `_2x3_TwoHills_Conquest_6P` | Conquest, file suffix `_6P` |
| Two Hills | `_2x3_TwoHills_Destruction_6P` | Destruction, file suffix `_6P` |

</details>

<details>
<summary>Helbe (12 scenario IDs)</summary>

Workshop Mod List `3762638679`.

| Map | Scenario ID | Size |
| --- | --- | --- |
| Helbe | `_5x3_Helbe_4v4_CONQ` | 4v4 Conquest |
| Helbe | `_5x3_Helbe_10v10_CONQ` | 10v10 Conquest |
| Hochland | `_5x3_HelbeHochland_2v2_CONQ` | 2v2 Conquest |
| Norden | `_5x3_HelbeNorden_2v2_CONQ` | 2v2 Conquest |
| Stream | `_5x3_HelbeStream_2v2_CONQ` | 2v2 Conquest |
| Stream | `_5x3_HelbeStream_3v3_CONQ` | 3v3 Conquest |
| Stream | `_5x3_HelbeStream_10v10_CONQ` | 10v10 Conquest |
| Suden | `_5x3_HelbeSuden_1v1_CONQ_DUEL` | 1v1 Conquest duel |
| Wide | `_5x3_HelbeWide_4v4_CONQ` | 4v4 Conquest |
| Wide | `_5x3_HelbeWide_10v10_CONQ` | 10v10 Conquest |
| Zentrum | `_5x3_HelbeZentrum_3v3_CONQ` | 3v3 Conquest |
| Zentrum | `_5x3_HelbeZentrum_10v10_CONQ` | 10v10 Conquest |

Army General file names:

- `SM_FO_5x3_Helbe_01`
- `SM_FO_5x3_Helbe_02`
- `SM_FO_5x3_Helbe_03`
- `SM_PL_5x3_Helbe_01`
- `SM_PL_5x3_Helbe_02`
- `SM_PL_5x3_Helbe_03`
- `SM_PL_5x3_Helbe_04`
- `SM_PL_5x3_Helbe_05`

</details>

<details>
<summary>Base game (102 scenario IDs)</summary>

Leave **Workshop Mod List** and **Workshop Mod Tags** empty. These are the Map Base Id values from Eugen's [Docker Hub page](https://hub.docker.com/r/eugensystems/warno).

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

</details>

### A second server

Each server is its own container. Add another one from this same template. Do not use Unraid's reinstall action. Reinstall replaces the container you already have.

The container name, Game Port, Settings Folder, and Server Name are unique. The directory before `/settings` is that container's Game Port. The next container adds 1 to that port, in both the Game Port field and that directory.

| Field | First server | Second server |
| --- | --- | --- |
| Name | `WARHOST` | `WARHOST2` |
| Game Port | `10400` | `10401` |
| Settings Folder | `/mnt/user/appdata/warno/10400/settings` | `/mnt/user/appdata/warno/10401/settings` |
| Server Name | `WARHOST - Hesse 2v2` | a different name |

Map, Workshop Mod List, and Workshop Mod Tags also belong to each container, so one server can run the Red Dragon map pack while another runs a base-game map. Public WAN IP, Eugen login, and Eugen dedicated key stay the same for up to five servers. A sixth container needs another login and key pair. Forward each Game Port to this Unraid server as TCP and UDP. Players join from the WARNO server browser by Server Name. They are not given a port to type.

Every container uses the same image, stored once. The settings folder holds `login.ini`, `variables.ini`, and `params_for_ai.json`. The wrapper also creates `warhost.lock` there so two running containers cannot share the folder. Do not copy WARNO or a Workshop folder into it. If the folder is already in use, or the game port is already taken, the start stops and the log says what to change. One pair runs five servers: fifteen servers need three pairs, fifty need ten, and one hundred needs twenty.

## Settings files

On each start, **Write Config From Form** (`true`) rewrites these files in the settings folder:

- `login.ini`
- `variables.ini`
- `params_for_ai.json`

When Workshop Mod List holds a bare Workshop id, the start also writes `warhost-workshop-versions.txt`: one line per id with Steam's update time and the `Version` written. Delete it to make the next start read each `Config.ini` again.

The wrapper writes those files in a private `.warhost-stage.*` folder first, then moves them into place. The next start that locks the settings folder removes one left by a crash or power loss, so do not keep anything under that name.

`samples/` shows the shape of those files with placeholders only. Do not replace the placeholders in this repository.

The faction matchup is NATO vs PACT (`GameType = 0`). Teams must stay the same size (`DeltaMaxTeamSize = 0`). AI decks are empty. RCON is not configured.

Set **Write Config From Form** to `false` only when you need to edit those files by hand. While it is `true`, the next start overwrites hand edits. While it is `false`, the three files stay as edited, `login.ini` is set to mode `600`, and no Workshop id is looked up on Steam. Any other file the server itself creates in that folder (for example `admins.ini` or `banned_clients.ini`, if it creates them) is left alone.

## Keys

Login from Eugen's reply, exactly as written. Not your Steam name; this login and the key are a matching pair good for five containers.

The dedicated key belongs in the Unraid form, which stores it for that container and writes `login.ini` on the server. The form shows the key in clear text so servers can be told apart. The startup log names only the last 4 characters. The key does not belong in this git repository, in an example file, or in a GitHub issue. If a key is ever committed, treat it as compromised even after a later delete, because git history keeps it. `.gitignore` ignores `login.ini` and a local `settings/` directory.

## Updates

Eugen publishes game updates as `eugensystems/warno:latest`. This repo does not copy their server launch arguments. `entrypoint-unraid.sh` writes the settings files and then runs `/server/entrypoint2.sh` from their image.

`.github/workflows/rebuild-image.yml` checks Eugen's image once a day, and also runs when the Dockerfile or entrypoint changes. If the digest changed, it builds `ghcr.io/suchamoneypit/warhost:latest`. In Unraid, update each server container. A failed Action leaves the previous image in place. Fix the Action and run it again. Players on a new WARNO patch need that rebuild before the dedicated server will match the client.

Change the entrypoint only if Eugen renames `entrypoint2.sh` or the settings filenames. A normal game patch does not require an edit here.

Workshop mods update apart from the image. Each start reads the current `Version` of every bare id in Workshop Mod List, so after a mod author publishes, restart the container. Until that restart, players who have the update are refused. A pinned `id/version` keeps its number until you change the field.

## Publishing the image (maintainers)

The image is already published. If you fork this repository, repeat these steps once your files are on `main`:

1. In the GitHub repository settings, enable Issues.
2. Under Actions, allow GitHub Actions, and set workflow permissions to read and write.
3. Run the **Rebuild WARHOST image** workflow.
4. Open the package `warhost` and set its visibility to Public. Unraid cannot pull a private package. The workflow tries to do this for `warhost`, and the package page is the place to confirm it.

Then install the template on your Unraid server and confirm the container stays up, the settings files contain your key only on that server, and the preset Hesse map is the running scenario. Submit the repository to Community Apps after that test.

Community Apps reads the default branch, `main`. A first submission needs that branch to be a public, active repository, with the MIT `LICENSE` at the root, `ca_profile.xml` with a non-empty Profile, and `templates/warhost.xml`. Open [https://ca.unraid.net/submit](https://ca.unraid.net/submit), run Validate, then Scan, and submit when the scan is clean. Those two buttons need your Community Apps login. The help pages are [submission help](https://ca.unraid.net/submit/help), [repository XML](https://ca.unraid.net/submit/help/repository-xml), and [repository information XML](https://ca.unraid.net/submit/help/repository-info-xml).

## License

Templates, metadata, documentation, and `entrypoint-unraid.sh` are under the MIT license in [`LICENSE`](LICENSE). Copyright 2026 suchamoneypit. GitHub detects that file as MIT, an OSI-approved license. Community Apps asks for that license on the repository contents: the templates, metadata, and docs. The template `<License>` tag is `https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/LICENSE`. The template `<ReadMe>` tag is `https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/README.md`.

The image is built `FROM eugensystems/warno`. The [Docker Hub page](https://hub.docker.com/r/eugensystems/warno), read on 2026-10-09, states no license for that image. Community Apps treats the container image license as separate from this repository's `LICENSE`. The Dockerfile leaves the image license unlabeled.

The image also contains [DepotDownloader 3.4.0](https://github.com/SteamRE/DepotDownloader/releases/tag/DepotDownloader_3.4.0), unmodified, under GPL-2.0. Its `LICENSE` is in `/opt/depotdownloader` in the image, and its source is at that release tag.

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

WARNO was a game made in France, but WARHOST was created in the United States.


## Support

Questions and problems go to [GitHub issues](https://github.com/suchamoneypit/WARHOST/issues). Leave the Eugen key out of the issue.
