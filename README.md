# WARHOST — WARNO Dedicated Server for Unraid

A mod-friendly, multi-instance capable WARNO dedicated server manager for Unraid. One [WARNO](https://store.steampowered.com/app/1611600/WARNO/) dedicated server per container. The install form takes your Eugen login and dedicated key (provided by Eugen upon request) and writes `login.ini`. The WebUI writes `variables.ini`. The container then runs the entrypoint from the official `eugensystems/warno` image.

The first start seeds a 2v2 Conquest lobby on the base-game map Hesse (`_2x2_Hesse_2vs2_CONQ`), named `WARHOST - default server name`, with no workshop mods, so players need only the game. Open the WebUI to set the server name, map, player limits, and workshop mods. Save and restart on that page restarts the dedicated server so the save loads. If the page cannot restart the container, restart it in Unraid. To host the [Red Dragon map pack](https://steamcommunity.com/sharedfiles/filedetails/?id=3811913066) (Steam Workshop item `3811913066`), check `3811913066` on that page and choose a scenario ID from the [scenario lists](#scenario-ids). A save writes the bare id. The next start reads that mod's current `Version` from Steam and writes `id/Version`. After the author publishes an update, use Save and restart in the WebUI. A pin already stored as `id/Version` stays until that save.

If you have hosted game servers before, the field descriptions on the Unraid form and a TCP and UDP port forward are likely all you need. For the full walkthrough, follow [docs/INSTALL-UNRAID.md](docs/INSTALL-UNRAID.md). It covers the Eugen key request, router setup, the Unraid 7 install route, every field, how to confirm the server works, and troubleshooting. This README is the reference.

## What you need

- A dedicated-server **login and key** from Eugen. Email `eugsupport@eugensystems.com` with the email address of your EugNet account and ask for a dedicated-server key; Eugen replies with a login and key pair ([Docker Hub](https://hub.docker.com/r/eugensystems/warno)). A dedicated key from another Eugen game also works. One pair can run up to five servers.
- Your **public WAN IP**, and the game port forwarded on your router **as both TCP and UDP** to the Unraid server. Eugen recommends host networking and this container uses it, so Unraid shows no Docker port mapping.
- Outbound internet from the Unraid server, so the game server can reach Eugen's master server (no offline LAN play), and so each start can read a Workshop mod's `Version` from Steam.


## Install

WARHOST is listed in Community Applications. In the Unraid **Apps** tab, search for **WARHOST**, choose **Install**, fill in the [form fields](#form-fields), and **Apply**. That installs the `main` template, which runs `ghcr.io/suchamoneypit/warhost:latest`.

### Without Community Applications

Use this route for the `dev` template, or to install a template change before Community Applications picks it up. Unraid 7 has no field for a template URL (Unraid 6.10 removed it), so copy the template to the flash drive and pick it from the **Template** dropdown.

In a checkout of this repository, `sh scripts/print_template_fetch.sh` prints the command in step 1. In Cursor or Claude Code, `/unraid-script` prints that command for `main`, a separate command for `dev` (`my-WARHOST-dev.xml`), and a clean-slate command. Paste only the branch you are about to add. The download URL uses the repository name `WARHOST` and the template file on that branch. Applying a branch template still writes `my-WARHOST.xml`, because `<Name>` on each branch is `WARHOST`, and leaves the suffixed file in the dropdown. The clean-slate command removes the `WARHOST` and `WARHOST-dev` containers and those template files. It also drops those names from `/var/lib/docker/unraid-autostart` and deletes the two private files under `/boot/config/plugins/community.applications/private/suchamoneypit/`. It removes the image named in that template's `<Repository>` only when no container is still using it. On `main` that image is `ghcr.io/suchamoneypit/warhost:latest`. On `dev` it is `ghcr.io/suchamoneypit/warhost:dev`. It also removes `/mnt/user/appdata/warno/<port>/settings` for those containers, which holds the login and key. A folder still mounted by another container is left in place.

1. Unraid web UI → terminal icon (`>_`):

   ```sh
   mkdir -p /boot/config/plugins/dockerMan/templates-user
   curl -fsSL -o /boot/config/plugins/dockerMan/templates-user/my-WARHOST.xml \
     https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/templates/warhost.xml
   ```

2. **Docker → Add Container → Template → User templates**, choose **WARHOST**, fill in the fields below, **Apply**.

The dropdown label is the flash filename with `my-` removed, so `my-WARHOST.xml` shows **WARHOST**. On Apply, Unraid writes `/boot/config/plugins/dockerMan/templates-user/my-<Name>.xml` from the Name on the form. With Name left as `WARHOST`, that is this download. A different Name leaves this file in the dropdown as a second entry, still labeled **WARHOST**. Delete an earlier download if it is still in that folder: `warno-dedicated-server.xml` or `my-WARNO-Dedicated-Server.xml`. This route is the one the Community Applications author gives for Unraid 6.10 and later. On 2026-10-09 Unraid 7.3.3 showed `my-WARHOST.xml` in that dropdown as **WARHOST**. The install guide records what that try did and did not prove. `sh scripts/print_template_fetch.sh --private` saves `warhost.xml` under `/boot/config/plugins/community.applications/private/suchamoneypit/`. The full command is in the install guide.

The template on `main` installs `ghcr.io/suchamoneypit/warhost:latest`. That tag is published when **Rebuild WARHOST image** runs on `main`. The template on `dev` installs `ghcr.io/suchamoneypit/warhost:dev`, published from `dev`. The pull check is in the install guide, step 2. The first server's settings folder is `/mnt/user/appdata/warno/10400/settings`. Containers from `main` share `ghcr.io/suchamoneypit/warhost:latest`; containers from `dev` share `ghcr.io/suchamoneypit/warhost:dev`. Extra search terms are `WARNO WARNO server dedicated server game server mods modded`.

### Form fields

<table>
<thead>
<tr>
<th align="left" nowrap>Field</th>
<th align="left">What to enter</th>
</tr>
</thead>
<tbody>
<tr>
<td nowrap>Settings Folder</td>
<td><code>/mnt/user/appdata/warno/10400/settings</code> for the first server. The next container uses this path with the port number plus 1, for example <code>/mnt/user/appdata/warno/10401/settings</code>. The folder holds the ini files only.</td>
</tr>
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
<td nowrap>WebUI</td>
<td><code>true</code>. Serves the WebUI on this Unraid host at the game port plus 1000, so <code>10400</code> uses <code>http://&lt;unraid&gt;:11400/</code>. Do not forward that port. The log says <code>WebUI listening on port 11400.</code> <code>false</code> leaves the Docker WebUI button with nothing listening. The log says <code>WebUI is off. Nothing is listening on port 11400.</code> If that port is already taken, it says <code>WebUI is off. Port 11400 is already in use.</code> Saving writes <code>variables.ini</code>. Save and restart on that page restarts the dedicated server to load it. If the page cannot, restart the container in Unraid. The Docker WebUI button opens 11400, which is the first server only.</td>
</tr>
<tr>
<td nowrap>Game Port</td>
<td><code>10400</code> for the first server. The next container uses that number plus 1. Forward each number to this Unraid server as TCP and UDP. Players join by the server name set in the WebUI.</td>
</tr>
<tr>
<td nowrap>Write Config From Form (Show more settings)</td>
<td><code>true</code>. Rewrites <code>login.ini</code> on every start. A missing <code>variables.ini</code> is the Hesse preset. A missing <code>params_for_ai.json</code>, or a symlink, is two empty deck lists. A regular file is kept. A bare Workshop id already in <code>variables.ini</code> is refreshed to <code>id/Version</code>. <code>false</code> leaves the files and sets <code>login.ini</code> to mode 600.</td>
</tr>
</tbody>
</table>

On the form, WebUI follows Public WAN IP and Game Port follows WebUI. **Show more settings** holds Write Config From Form. The first start seeds Hesse 2v2 (`_2x2_Hesse_2vs2_CONQ`) with no workshop mods and the server name `WARHOST - default server name`. Two new containers both use that name until each is changed in its WebUI. Scenario IDs and named mods are in the tables below.

A container saved from an earlier template can still show Server Name, Map, player counts, combat rule, and the workshop fields. This entrypoint ignores those values and prints `Lobby settings on the Docker template are ignored. Change the server in the WebUI.`

### Map

The WebUI map list uses a scenario ID from the [lists below](#scenario-ids). Base-game maps need no workshop mod. A workshop map needs its pack checked under Steam Workshop Maps on that page, from the [workshop mods](#workshop-mods) table. When the startup log warns about the map or the mod list, the [troubleshooting table](docs/INSTALL-UNRAID.md#troubleshooting) in the install guide says what to change.

The size in the ID is the usual lobby. Eugen's [variables.ini](https://hub.docker.com/r/eugensystems/warno) page does not tie player count to that size. The usual settings are Max Players 2 and Team Size 1 for 1v1, 4 and 2 for 2v2, 6 and 3 for 3v3, 8 and 4 for 4v4, and 20 and 10 for 10v10. Choosing a map in the WebUI fills Max players (`NbMaxPlayer`), Team size (`MaxTeamSize`), and Minimum players (`NbMinPlayer`) from that map. Minimum players is 2 when the usual lobby has at least two players. PvE hides those three; PvP keeps them editable, and a save writes what they show, so a 2v2 map can be saved as 8 and 4 or as a 1v1 (max 2, team size 1, minimum 2). A count already in `variables.ini` is what the page shows until the map is changed.

#### Workshop mods

The WebUI checklist loads the mod that contains the maps. Check the Workshop id from the table. Save writes the bare id. The next start reads that mod's current `Version` and writes `id/version`. Pick the map from that mod's scenario list below. Red Dragon is the first row: check `3811913066`, which sets tags `Maps-Scenarios`, and choose `RDPort_JungleLaw_2v2_CONQ` for Jungle Law.

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

The pin column is each mod's `Version` from its `Config.ini`, read on 2026-10-09 (Red Dragon on 2026-10-10). A pin holds that number, so players are refused once the author increments `Version`. The WebUI writes the bare id. A pin already in `variables.ini` stays until that mod is saved again from the page.

Galactic Divide is a total conversion and A World in Flames is a modern-day overhaul. Neither has scenario IDs of its own, so the map comes from the base game or a map pack. Check a conversion and a map pack together. The page joins their ids with a hyphen, for example `3595948209-3811913066`. Tags are the union of the checked mods. A World in Flames uses `Gameplay-Interface` alone, and `Gameplay-Interface-Maps-Scenarios` when a map pack is also checked.

Joining players subscribe to each Workshop item in the list and enable it in WARNO's Mod Center. Eugen's [variables.ini](https://hub.docker.com/r/eugensystems/warno) page says a joining player who is missing a `ModList` mod is prompted to download and enable it. To read `Version`, the container downloads just the mod's `Config.ini` from Steam with [DepotDownloader](https://github.com/SteamRE/DepotDownloader), on the first start and after each update the author publishes.

#### Scenario IDs

Map packs come first and the base game is last. Choose the value from the **Scenario ID** column in the WebUI. The `SM_` names under some packs are Army General files; pick a scenario from the tables. For a mod not listed here, [step 4 of the install guide](docs/INSTALL-UNRAID.md#4-decide-the-map-and-find-a-scenario-id) shows how to find its IDs. An id already in `variables.ini` that is not in this list stays if you leave it checked.

<details>
<summary>Red Dragon map pack (28 scenario IDs)</summary>

Check `3811913066` in the WebUI checklist. Every map is Conquest, so leave combat rule as the page sets it.

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

Leave the WebUI workshop checklist clear. These are the Map Base Id values from Eugen's [Docker Hub page](https://hub.docker.com/r/eugensystems/warno).

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

The container name, Game Port, and Settings Folder are unique. The server name is set in that container's WebUI, and it has to differ from the other servers. The directory before `/settings` is that container's Game Port. The next container adds 1 to that port, in both the Game Port field and that directory.

| Field | First server | Second server |
| --- | --- | --- |
| Name | `WARHOST` | `WARHOST2` |
| Game Port | `10400` | `10401` |
| Settings Folder | `/mnt/user/appdata/warno/10400/settings` | `/mnt/user/appdata/warno/10401/settings` |
| Server name in the WebUI | `WARHOST - default server name` until you change it | a different name |

The map and workshop mods also belong to each container, so one server can run the Red Dragon map pack while another runs a base-game map. Public WAN IP, Eugen login, and Eugen dedicated key stay the same for up to five servers. A sixth container needs another login and key pair. Forward each Game Port to this Unraid server as TCP and UDP. Players join from the WARNO server browser by server name. They are not given a port to type.

Every container uses the same image, stored once. The settings folder holds `login.ini`, `variables.ini`, and `params_for_ai.json`. The wrapper also creates `warhost.lock` there so two running containers cannot share the folder. Do not copy WARNO or a Workshop folder into it. If the folder is already in use, or the game port is already taken, the start stops and the log says what to change. One pair runs five servers: fifteen servers need three pairs, fifty need ten, and one hundred needs twenty.

## Settings files

On each start, **Write Config From Form** (`true`) rewrites `login.ini` in the settings folder. It creates `variables.ini` only when that file is missing, using the Hesse preset, and creates `params_for_ai.json` only when that file is missing, as two empty deck lists. An existing `variables.ini` stays, except a bare Workshop id in `ModList`, which that start rewrites as `id/Version`. A symlink at `params_for_ai.json` is replaced; a regular file is kept.

When `ModList` holds a bare Workshop id, the start also writes `warhost-workshop-versions.txt`: one line per id with Steam's update time and the `Version` written. Delete it to make the next start read each `Config.ini` again, after a WebUI save has put the bare id back.

The wrapper writes those files in a private `.warhost-stage.*` folder first, then moves them into place. The next start that locks the settings folder removes one left by a crash or power loss, so do not keep anything under that name.

`samples/` shows the shape of those files with placeholders only. Do not replace the placeholders in this repository.

The faction matchup is NATO vs PACT (`GameType = 0`). Teams must stay the same size (`DeltaMaxTeamSize = 0`) until a PvE setup save says otherwise. The first `params_for_ai.json` has no decks. RCON is not configured.

Set **Write Config From Form** to `false` only when you need to edit those files by hand. While it is `true`, the next start still rewrites `login.ini`, leaves an existing `variables.ini` and an existing `params_for_ai.json` in place, and refreshes bare Workshop ids in `variables.ini`. While it is `false`, the three files stay as edited, `login.ini` is set to mode `600`, and no Workshop id is looked up on Steam. Any other file the server itself creates in that folder (for example `admins.ini` or `banned_clients.ini`, if it creates them) is left alone.

## WebUI

**WebUI** defaults to `true` and sits on the main form after Public WAN IP, before Show more settings. The container serves the WebUI at the game port plus 1000. That is the page the Docker WebUI button opens. Game port `10400` is `http://<unraid>:11400/`. The next server, on `10401`, is `http://<unraid>:11401/`. Do not forward the page port. The game port stays the one you forward as TCP and UDP. The Docker WebUI button uses `http://[IP]:[PORT:11400]/`. On host networking that button opens 11400, so it matches the first server only. When the page is accepting connections, the log says `WebUI listening on port 11400.` before the game server output.

Set it to `false` and no extra process listens. The dedicated server starts the same way. The log says `WebUI is off. Nothing is listening on port 11400.` If that port is already taken, the log says `WebUI is off. Port 11400 is already in use.` The Docker WebUI button still opens that port, so the browser reports that the address refused to connect.

Steam Workshop Maps is a checklist of the named map packs. Full conversions and other mods, such as Galactic Divide and A World in Flames, are a second checklist on the right of that section. Checking a map pack shows that pack's maps below the base-game list. Two or more checked packs use a dropdown to switch packs. Galactic Divide and A World in Flames add no map rows. An id already in `variables.ini` that is not in either list is a checkbox on that right-hand list, labeled Workshop id and that id. The map list shows the base-game maps. Search matches the map name and scenario ID. Size and combat rule stay separate dropdowns. For a map in the list, the combat rules menu offers only that scenario's rule, and a save with the other rule is rejected. A saved map that is not in the list still offers both. Setup, above Game parameters, is PvP or PvE setup. PvP keeps Max players, Team size, and Minimum players, and a PvP save does not write `params_for_ai.json`. PvE setup hides those three. Humans play as one side, and the AI count fills the other. A save writes `CoopVsAI` (`1` or `2`), sets minimum players to the human count, max players to the two counts added together, and team size to the larger count. The team difference is that gap. Eugen documents one team cap for each team, so the human side can fill up to that cap. A larger AI side has not been confirmed on a running server. The save also writes at least one AI deck into `params_for_ai.json`: a name, a deck code, and a difficulty from 1 to 6. Switching back to PvP sets `CoopVsAI` to `0` and the team difference to `0`, and leaves the deck file. The match dropdowns are command and control, combat rules, opposition, starting resources, income, score limit, and time limit. Save writes the server name, the selected map, the checked mods as bare ids, and those dropdowns into `variables.ini`. Tags are derived from the checked mods. A modded map whose pack is unchecked is rejected. An unknown id stays, including a pin, when it remains checked. Save keeps the previous copy as `variables.ini.bak` and leaves the current match running. Save and restart writes the form when it differs from that file, then restarts the dedicated server, which stops the match. If the page cannot restart the container, restart it in Unraid. Max players, team size, and minimum players start from the selected map and can be edited; the save writes those values.

If the page fails to start, or its port is already taken, the log warns and the game server still starts. A privilege drop that fails leaves the page running and the container log warns that it stayed root. The page does not show the Eugen login or dedicated key. Scenic view and tactical zones stay text until `webui/previews` is filled from a local WARNO install. That folder is not in the published image. `ghcr.io/suchamoneypit/warhost:latest` and `ghcr.io/suchamoneypit/warhost:dev` both serve the WebUI and start with Map unset once **Rebuild WARHOST image** has published that tag. A container still on the `:latest` image from before the v1.10 publish opens port 11400 with nothing listening, and that image still stops when Map is unset.

## Keys

Login from Eugen's reply, exactly as written. Not your Steam name; this login and the key are a matching pair good for five containers.

The dedicated key belongs in the Unraid form, which stores it for that container and writes `login.ini` on the server. The form shows the key in clear text so servers can be told apart. The startup log names only the last 4 characters. The key does not belong in this git repository, in an example file, or in a GitHub issue. If a key is ever committed, treat it as compromised even after a later delete, because git history keeps it. `.gitignore` ignores `login.ini` and a local `settings/` directory.

## Updates

Eugen publishes game updates as `eugensystems/warno:latest`. This repo does not copy their server launch arguments. `entrypoint-unraid.sh` writes the settings files and then runs `/server/entrypoint2.sh` from their image. It stays the container's main process. Save and restart runs that start again so the saved lobby and Workshop versions load.

`.github/workflows/rebuild-image.yml` checks Eugen's image once a day. The workflow also runs when the Dockerfile, `entrypoint-unraid.sh`, `webui/`, or `.github/workflows/rebuild-image.yml` changes, and a push of those paths publishes `:latest` from `main` or `:dev` from `dev`. In Unraid, update each server container. A failed Action leaves the previous image in place. Fix the Action and run it again. Players on a new WARNO patch need that rebuild before the dedicated server will match the client.

Change the entrypoint only if Eugen renames `entrypoint2.sh` or the settings filenames. A normal game patch does not require an edit here.

Workshop mods update apart from the image. A WebUI save writes bare ids. The next start reads the current `Version` of each bare id in `variables.ini` and writes `id/Version`. After a mod author publishes, use Save and restart in the WebUI. Until that restart, players who have the update are refused. A pin already stored as `id/version` keeps its number until that save.

## Publishing the image (maintainers)

The image is already published. Before merging `dev` into `main`, set `<Repository>` in `templates/warhost.xml` back to `ghcr.io/suchamoneypit/warhost:latest`. If you fork this repository, repeat these steps once your files are on `main`:

1. In the GitHub repository settings, enable Issues.
2. Under Actions, allow GitHub Actions, and set workflow permissions to read and write.
3. Run the **Rebuild WARHOST image** workflow.
4. Open the package `warhost` and set its visibility to Public. Unraid cannot pull a private package. The workflow tries to do this for `warhost`, and the package page is the place to confirm it.

Then install the template on your Unraid server and confirm the container stays up, the settings files contain your key only on that server, and the preset Hesse map is the running scenario. Submit the repository to Community Apps after that test.

Community Apps reads the default branch, `main`. A first submission needs that branch to be a public, active repository, with the MIT `LICENSE` at the root, `ca_profile.xml` with a non-empty Profile, and `templates/warhost.xml`. Open [https://ca.unraid.net/submit](https://ca.unraid.net/submit), run Validate, then Scan, and submit when the scan is clean. Those two buttons need your Community Apps login. The help pages are [submission help](https://ca.unraid.net/submit/help), [repository XML](https://ca.unraid.net/submit/help/repository-xml), and [repository information XML](https://ca.unraid.net/submit/help/repository-info-xml).

## License

Templates, metadata, documentation, `entrypoint-unraid.sh`, and `webui/` are under the MIT license in [`LICENSE`](LICENSE). Copyright 2026 suchamoneypit. GitHub detects that file as MIT, an OSI-approved license. Community Apps asks for that license on the repository contents: the templates, metadata, and docs. The template `<License>` tag is `https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/LICENSE`. The template `<ReadMe>` tag is `https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/README.md`.

The image is built `FROM eugensystems/warno`. The [Docker Hub page](https://hub.docker.com/r/eugensystems/warno), read on 2026-10-09, states no license for that image. Community Apps treats the container image license as separate from this repository's `LICENSE`. The Dockerfile leaves the image license unlabeled.

The image also contains [DepotDownloader 3.4.0](https://github.com/SteamRE/DepotDownloader/releases/tag/DepotDownloader_3.4.0), unmodified, under GPL-2.0. Its `LICENSE` is in `/opt/depotdownloader` in the image, and its source is at that release tag.

## Documentation

| File | Contents |
| --- | --- |
| [docs/INSTALL-UNRAID.md](docs/INSTALL-UNRAID.md) | First install, step by step, with verification and troubleshooting |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the wrapper, WebUI, and image behave, with sources |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Why things are the way they are |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Goals and known issues |
| [docs/UNRAID-TEMPLATE-GUIDE.md](docs/UNRAID-TEMPLATE-GUIDE.md) | Generic Unraid template guidance, reusable for other game servers |
| [docs/AI-WORKFLOW.md](docs/AI-WORKFLOW.md) | Working on this repository with Cursor and Claude Code |

## Made with AI tools

This project was built with AI coding assistants (mainly [Cursor](https://cursor.com)). Humans directed the work, reviewed what shipped, and remain responsible for it. Treat the template like any other community Docker or Unraid project: verify on your own server, and open an issue if something is wrong. Notes for working on the agent setup in this repository are in [docs/AI-WORKFLOW.md](docs/AI-WORKFLOW.md).

WARNO was a game made in France, but WARHOST was created in the United States.


## Support

Questions and problems go to [GitHub issues](https://github.com/suchamoneypit/WARHOST/issues). Leave the Eugen key out of the issue.
