# First install on Unraid 7.x

WARNO was a game made in France, but WARHOST was created in the United States.

A step-by-step guide from nothing to a WARHOST container running a WARNO dedicated server that players can join. It is written for someone who has never installed a container outside Community Applications.

What this guide rests on, checked on 2026-10-09:

- Eugen's instructions on [Docker Hub](https://hub.docker.com/r/eugensystems/warno) (key request, settings files, host networking, TCP and UDP).
- The image the `main` template installs, `ghcr.io/suchamoneypit/warhost:latest`, after **Rebuild WARHOST image** has published it. The `dev` template installs `ghcr.io/suchamoneypit/warhost:dev`. Entrypoint `/server/entrypoint-unraid.sh`.
- Unraid's [container management docs](https://docs.unraid.net/unraid-os/manual/docker-management/) and the Community Applications author's statement that Unraid 6.10 [removed the Template Repositories field](https://forums.unraid.net/topic/112170-allow-template-repositories-to-be-hosted-from-other-sources/).
- The Red Dragon map pack files on a PC subscribed to Steam Workshop item `3811913066`.

What it does not rest on: a full recorded pass of steps 5 to 7. On 2026-10-09 two containers showed online; section 8 records that. The list at the end says what that run did not cover. If you complete a step that is still open, record what you saw in `docs/ROADMAP.md`.

## 0. Checklist before you start

You need all of these. Items marked **you** cannot be done by anyone else.

| Item | How |
| --- | --- |
| **you** Eugen dedicated-server login and key | Step 1. Allow for a reply delay; Eugen's page gives no turnaround time. |
| **you** Your public WAN IP | Step 3. |
| **you** Router port forward | Step 3. |
| An Unraid 7.x server with Docker enabled and the array started | Settings → Docker → Enable Docker: Yes. |
| The scenario ID of the map you want | Step 4. The first start seeds `_2x2_Hesse_2vs2_CONQ`, a base-game map. Change it in the WebUI. |
| For players: WARNO on Steam and, for the Red Dragon maps, Workshop item `3811913066` subscribed and enabled in WARNO's Mod Center | The Workshop page says so; the server does not install the mod for them. |

## 1. Request the Eugen login and key

Eugen's Docker Hub page says: request access by emailing `eugsupport@eugensystems.com` and "provide the email you used to create your EugNet account. We will send you back a login and apikey pair." If you already have a dedicated key from another Eugen game, it works for WARNO and you do not need to write. One login and key pair can run at most five servers.

What you get back is a **login** and a **key**. Enter the login exactly as it appears in Eugen's reply; do not assume it is your email address. Keep both out of GitHub, screenshots, and chat. The only places they belong are the Unraid form and the `login.ini` file the container writes on your server.

## 2. Confirm the image and template are published

The image to confirm is `ghcr.io/suchamoneypit/warhost:latest`. The repository is `WARHOST` (`https://github.com/suchamoneypit/WARNO-Dedicated-Server-Unraid` returned HTTP 301 to that name on 2026-10-09). Repeat the checks below if months have passed or you forked the repository.

- The template file must return `200`: <https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/templates/warhost.xml>. GitHub redirects the old repository URL. It does not redirect the old template filename.
- The template ReadMe is https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/README.md and the template License is https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/LICENSE.
- The image must be pullable without logging in. Open <https://github.com/suchamoneypit/WARHOST/pkgs/container/warhost>; the package must be **Public**. From any Linux or macOS terminal, this must print `200`:

  ```sh
  TOKEN=$(curl -s "https://ghcr.io/token?scope=repository:suchamoneypit/warhost:pull" | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
  curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.index.v1+json" \
    https://ghcr.io/v2/suchamoneypit/warhost/manifests/latest
  ```

- The last **Rebuild WARHOST image** run under the repository's **Actions** tab should be green. A red run means the published image is older than the repository; it still installs, but open an issue.
## 3. Network preparation

The container uses **host networking**, which Eugen recommends. That has three consequences:

1. Unraid shows **no port mapping** for this container. That is correct, not a missing field.
2. The game port must be free on the Unraid server itself. `10400` is this template's default; Eugen's docs use a placeholder. If something else on Unraid already uses `10400`, pick another port and use it everywhere below.
3. Every additional container needs the previous game port plus 1. Forward each of those ports as TCP and UDP. Players join by the server name set in the WebUI.

On your router, forward the game port **as both TCP and UDP** to your Unraid server's LAN IP. Eugen: "make sure you forward both UDP and the TCP to the exposed port because the server needs both." Give Unraid a fixed LAN IP (DHCP reservation) so the forward does not break.

Find your **public WAN IP** on the router's status page or at <https://www.whatismyip.com/> from a device on that network. The Add Container form cannot look this up for you. The server advertises exactly the address you type; it does not look it up. If your router's WAN address is in `100.64.0.0/10` (`100.64.` to `100.127.`), you are behind carrier-grade NAT; if it starts with `10.`, `172.16.` to `172.31.`, or `192.168.`, there is another router or NAT device upstream. In both cases a forward on your router alone will not reach you; forward on the upstream device too, or ask your ISP for a public address. If your public IP changes over time, you must update the field and restart the container.

The server also needs **outbound** internet. Eugen's start script in the image calls `warno-server` with `-ipmms 178.32.126.73 -portmms 10002`, so the server contacts Eugen's master server at that address. Eugen's image is 84 MB compressed. WARHOST adds DepotDownloader, a 79 MB program (33 MB as its release zip). The image contains no Steam library and is stored once no matter how many containers you add. With a bare Workshop id in `variables.ini`, each start also asks Steam whether that mod changed. On the first start, and after each update, it downloads the mod's `Config.ini` and its file list, under 1 MB for Red Dragon on 2026-10-10. What `warno-server` downloads at first start, and where, has not been observed. Do not copy WARNO or a Workshop folder into each settings directory.

## 4. Decide the map and find a scenario ID

The map is a scenario ID, not a map name. Eugen's page lists base-game IDs such as `_2x2_Hesse_2vs2_CONQ`; those need no mod, so leave the WebUI workshop checklist clear for them. For a Workshop map pack, the IDs are inside the mod's files, and the Workshop page does not publish them.

The first start seeds the base-game map Hesse 2v2, `_2x2_Hesse_2vs2_CONQ`, with no workshop mods and the server name `WARHOST - default server name`. For the Red Dragon map pack, check `3811913066` in the WebUI and choose `RDPort_JungleLaw_2v2_CONQ`; the page sets tags `Maps-Scenarios`. The README lists the same values, with Red Dragon first in the workshop mods table and in the scenario lists. Base-game IDs, that pack's IDs, and the named workshop mods are in `README.md`. Galactic Divide (`3595948209`) and A World in Flames (`3388575848`) have empty `Scenarios/` folders, so the map stays a scenario ID from the base game or a map pack. Tag words are in the README: Galactic Divide is `Gameplay-Interface-Sound-Scenarios-Maps`, and A World in Flames is `Gameplay-Interface`, or `Gameplay-Interface-Maps-Scenarios` when a map pack is also required. WEST FULDA 1.0 (`3363584349`), Highway to Oslo (`3474588989`), Ramstein Air Base (`3705706772`), Arsenal (`3415339374`), and Helbe (`3762638679`) have their scenario IDs in the README, read from each mod's `Scenarios/` folder on 2026-10-09. The Workshop pages still do not publish those IDs or the `Config.ini` `Version`. Each start reads `Version` for a bare id. The procedure below finds scenario IDs, and the number for a pin.

To find scenario IDs yourself, on any PC where Steam has downloaded the mod (subscribe in Steam, let it download):

1. Open the mod folder. The Workshop item ID is the number in the Workshop page URL.
   - Windows default: `C:\Program Files (x86)\Steam\steamapps\workshop\content\1611600\3811913066\`
   - Linux default: `~/.local/share/Steam/steamapps/workshop/content/1611600/3811913066/`
   - A second Steam library puts it under that library's `steamapps\workshop\content\1611600\`.
2. Open the `Scenarios` subfolder. Each scenario has four files named `<ScenarioID>_Assets.dat`, `<ScenarioID>_Definition.dat`, `<ScenarioID>_Details.dat`, `<ScenarioID>_GameData.dat`. The part before the suffix is the scenario ID. For Jungle Law the files are `RDPort_JungleLaw_2v2_CONQ_*.dat`.
3. To list them all, in the mod folder:

   ```sh
   ls Scenarios | sed -E 's/_(Assets|Definition|Details|GameData)\.dat$//' | sort -u
   ```

   PowerShell:

   ```powershell
   Get-ChildItem .\Scenarios -Name | ForEach-Object { $_ -replace '_(Assets|Definition|Details|GameData)\.dat$','' } | Sort-Object -Unique
   ```

4. The display name can differ from the ID. The Workshop page lists "Wonsan Harbour"; the file is `RDPort_WonsanNative_2v2_CONQ`.
5. `Config.ini` in the mod root confirms the item ID (`ID = 3811913066`) and shows the mod's own `Version` number (`27` on 2026-10-10). The comment on that line says to increment it when an update is incompatible with the current version. Clients compare that number with the one after the slash in `ModList`. Enter only the id, `3811913066`, and each start reads the current `Version` from Steam and writes the pair, `3811913066/27` on 2026-10-10. Eugen's page says the version in `ModList` "is usually always 0"; `/0` lets this server register and then the client rejects the join. A typed `id/version` is a pin and is written as typed: `3811913066/15` matched this pack on 2026-10-09 and does not match version 27.

Usual player counts for each size are in the README. A WebUI save sets them from the selected map. Eugen does not lock the lobby to the size in the scenario ID. All Red Dragon maps are Conquest, so the combat rule stays `2` for them. WEST FULDA 1.0, Highway to Oslo, Ramstein Air Base, and Arsenal include Destruction scenarios. Helbe's skirmish files are Conquest. Combat Rule is `2` when the scenario ID contains `CONQ` or `Conquest`, and `1` when it contains `DEST` or `Destruction`. Oslo, Ramstein, and Arsenal use the full words `Conquest` and `Destruction`.

## 5. Put the template into Unraid

Unraid 6.10 removed the **Template Repositories** URL box from the Docker tab, so there is no place to paste a template URL in Unraid 7. Until this template is in Community Applications, copy it onto the flash drive.

`sh scripts/print_template_fetch.sh`, run in a checkout of this repository, prints the command below. In the Unraid web UI, open the terminal (the `>_` icon top right) and paste it. `/unraid-script` prints this command, a separate command for `dev` under `my-<Name>-dev.xml`, and a clean-slate command. Paste only the branch you are about to add. On Apply, Unraid writes `my-<Name>.xml` from the Name field, which is `WARHOST` on each of these branches, so applying a branch template replaces `my-WARHOST.xml` and leaves the suffixed file in the dropdown. The clean-slate command removes the `WARHOST` and `WARHOST-dev` containers and those template files. It also drops those names from `/var/lib/docker/unraid-autostart` and deletes the two private files under `/boot/config/plugins/community.applications/private/suchamoneypit/`. It removes the template image only when no container is still using it. It also removes `/mnt/user/appdata/warno/<port>/settings` for those containers, which holds the login and key. A folder still mounted by another container is left in place.

```sh
mkdir -p /boot/config/plugins/dockerMan/templates-user
curl -fsSL -o /boot/config/plugins/dockerMan/templates-user/my-WARHOST.xml \
  https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/templates/warhost.xml
```

The `dev` template is a separate download. It installs `ghcr.io/suchamoneypit/warhost:dev`, which starts with Map unset and serves the WebUI. Paste this instead of the `main` command when that is the container you are adding. Wait until **Rebuild WARHOST image** has published that tag, or Apply cannot pull it.

```sh
mkdir -p /boot/config/plugins/dockerMan/templates-user
curl -fsSL -o /boot/config/plugins/dockerMan/templates-user/my-WARHOST-dev.xml \
  https://raw.githubusercontent.com/suchamoneypit/WARHOST/dev/templates/warhost.xml
```

Go to **Docker → Add Container**. Open the **Template** dropdown at the top and pick **WARHOST** for the `main` download, or **WARHOST-dev** for the `dev` download, under **User templates**. Every field prefills. The dev entry's repository is `ghcr.io/suchamoneypit/warhost:dev`.

Unraid labels that menu from the filename, with `my-` removed ([CreateDocker.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/CreateDocker.php), read 2026-10-09). The `<Name>` in the XML is `WARHOST`. That string is the Docker container name. It cannot contain spaces, so the Apps and dropdown title is `WARHOST`, and WARNO stays in the overview. Extra search terms are `WARNO WARNO server dedicated server game server mods modded`. If an earlier download is still in the folder, delete it:

```sh
rm -f /boot/config/plugins/dockerMan/templates-user/warno-dedicated-server.xml \
  /boot/config/plugins/dockerMan/templates-user/my-WARNO-Dedicated-Server.xml
```

The filename matches what Unraid writes on Apply (`my-<Name>.xml`, case preserved, in [DockerClient.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/DockerClient.php) `getUserTemplatePath`). On 2026-10-09 Unraid 7.3.3 showed `my-WARHOST.xml` in the Template dropdown as **WARHOST**. A file left from an earlier Apply kept the old fields until it was removed and this curl was run again. Close Add Container before curling. Apply on a tab that is already open writes that tab back over the file. The curl changes the form only. A download of `main` still runs `ghcr.io/suchamoneypit/warhost:latest`, which changes when a rebuild of that tag succeeds. A download of `dev` runs `ghcr.io/suchamoneypit/warhost:dev` after **Rebuild WARHOST image** has published that tag. That image starts with Map unset. `:latest` from `main` still stops when Map is unset. A file named `warno-dedicated-server.xml` was reported to show that lowercase name.

Alternative, still until Community Applications lists it: `sh scripts/print_template_fetch.sh --private` prints the command that saves the file where the Apps tab looks for private templates. Paste that instead:

```sh
mkdir -p /boot/config/plugins/community.applications/private/suchamoneypit
curl -fsSL -o /boot/config/plugins/community.applications/private/suchamoneypit/warhost.xml \
  https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/templates/warhost.xml
```

It then appears in the **Apps** tab under **Private**. The user-template download was tried with the lowercase filename, and the dropdown showed that name. The private-folder route has not been executed for this repository.

## 6. Fill in the form

Login from Eugen's reply, exactly as written. Not your Steam name; this login and the key are a matching pair good for five containers.

WebUI is on the main form, after Public WAN IP and before **Show more settings**. **Show more settings** holds Write Config From Form. The server name, map, player counts, combat rule, and workshop mods are set in the WebUI after the first start, then loaded by restarting that container. WebUI is on the `dev` template and defaults to `true`. The `main` download above still has the lobby fields on the form and WebUI default `false` behind Show more settings. A container added from that file keeps those fields until this template is published. The `dev` entrypoint ignores leftover lobby fields. The first start of a new settings folder writes the server name `WARHOST - default server name`. An existing `variables.ini` keeps the name already in that file. `ghcr.io/suchamoneypit/warhost:dev` serves the page and starts with Map unset. `ghcr.io/suchamoneypit/warhost:latest` still stops when Map is unset, and it does not serve the page until this work is published and that image rebuild finishes. Leave defaults alone unless the table says otherwise. Scenario IDs are in the README.

| Field | Default | Enter |
| --- | --- | --- |
| Name | `WARHOST` | Keep for the first server. Each added container needs its own name. |
| Network Type | `Host` | Keep. |
| Settings Folder | `/mnt/user/appdata/warno/10400/settings` | Keep when Game Port stays `10400`. If step 3 replaced that port, put the replacement in this path. The next container uses this path with the port number plus 1, for example `/mnt/user/appdata/warno/10401/settings`. These are small ini files. Do not copy the game here. |
| Eugen Login | empty | The login from Eugen's reply. |
| Eugen Dedicated Key | empty | The key from Eugen's reply. Shown in clear text on this form so servers can be told apart. |
| Public WAN IP | empty | Your public IP address from step 3. |
| WebUI | `true` | Keep. Serves the WebUI on this Unraid host at the game port plus 1000, so `10400` is `http://<this-unraid-host>:11400/`, and the log says `WebUI listening on port` followed by that page port. Do not forward that port. `false` leaves the Docker WebUI button with nothing listening. The log says `WebUI is off. Nothing is listening on port` followed by the game port plus 1000. If that port is already taken, it says `WebUI is off. Port 11400 is already in use.` when the game port is `10400`. Open that page to set the server name, map, and workshop mods. Save writes `variables.ini`; restart the container to load it. A modded map whose pack is unchecked is rejected. The Docker WebUI button opens 11400, the first server only. |
| Game Port | `10400` | Keep for the first server. The next container uses this number plus 1. Forward each number as TCP and UDP. Players join by the server name set in the WebUI. You can change a port later by editing that container; the forward must use the same number. |
| Write Config From Form (Show more) | `true` | Keep. Rewrites `login.ini` and `params_for_ai.json` on every start. Creates `variables.ini` with the Hesse preset when that file is missing, and refreshes bare Workshop ids already in an existing file. |

Click **Apply**. Unraid pulls the image and starts the container. A pull error here means Unraid could not fetch the image; the first troubleshooting row and step 2 cover the usual causes.

## 7. Confirm it works

Work through these in order. Each one proves something different.

### 7a. The container started

On the **Docker** tab the container shows as started. Click its icon → **Logs**. With a new settings folder, the first wrapper line is `Wrote WARNO settings for WARHOST - default server name on port 10400. Map _2x2_Hesse_2vs2_CONQ. Key last 4` and the last 4 characters of the key. An existing `variables.ini` is kept, and that line starts with `Kept variables.ini for` plus the name and map in the file. A container that still passes the old lobby fields also prints `Lobby settings on the Docker template are ignored. Change the server in the WebUI.` When `ModList` holds a bare Workshop id, one line per id comes first: `Workshop item 3811913066 is Version 27, read from its Config.ini...` when the id is new to this settings folder or has changed on Steam, and `Workshop item 3811913066 is unchanged on Steam since the last check. Version 27.` otherwise. The kept line then names `ModList`, and the wrapper prints the Config.ini comparison line. It adds `warning: Workshop Mod List contains 3811913066/0` or `warning: Workshop Mod List contains 3811913066/15` when that pair is in the file on a Red Dragon map, and `warning: Map ... is not a Red Dragon scenario` when the list contains `3811913066` and Map does not start with `RDPort_`. It adds `warning: Workshop Mod List is empty and Map ... is not a base-game scenario` when the list is empty and Map is not one of the base-game IDs in the README, and `note: Workshop Mod Tags is ... and Workshop Mod List is empty` when tags are set without a mod. The next line names the next container's Game Port. With the preset, WebUI is `true`, and the last line before Eugen's output is `WebUI listening on port 11400.` Set WebUI to `false` and that line is `WebUI is off. Nothing is listening on port 11400.` Eugen's output follows.

```text
Wrote WARNO settings for WARHOST - default server name on port 10400. Map _2x2_Hesse_2vs2_CONQ. Key last 4 XXXX.
Next container on this host: Game Port 10401, settings folder /mnt/user/appdata/warno/10401/settings, and a different Server Name in the WebUI. One login and key runs five servers. Players join by Server Name.
WebUI listening on port 11400.
```

Eugen's server prints after those wrapper lines. Nobody has recorded the full healthy `warno-server` log; when you see it, add it to this file. If the container stopped **before** printing the `Wrote WARNO settings` line, the last log line is one of the wrapper's own error messages (first rows of the troubleshooting table). If it stopped **after** Eugen's output begins, the wrapper did its job and `warno-server` itself exited; read the lines after it and use the later rows.

### 7b. The settings files exist

From the Unraid terminal:

```sh
ls -la /mnt/user/appdata/warno/10400/settings/
grep -E '^(ServerName|Map|ModList) ' /mnt/user/appdata/warno/10400/settings/variables.ini
```

Expect `login.ini`, `variables.ini`, and `params_for_ai.json` with mode `-rw-------`, and `Map = _2x2_Hesse_2vs2_CONQ` with no `ModList` line. A `.warhost-stage.*` directory should not remain after this start. `warhost.lock` is the wrapper's lock file. After a WebUI save that checks a workshop mod, and the restart that follows, `warhost-workshop-versions.txt` lists each bare id, Steam's update time, and the `Version` written. Do not display `login.ini` on a shared screen; it contains the key.

### 7c. The port is open on Unraid

Still in the Unraid terminal:

```sh
ss -lunp | grep 10400
ss -ltnp | grep 10400
```

With host networking the `warno-server` process appears directly in that list. Eugen says the server needs both protocols; which sockets it actually opens has not been recorded. Note what you see.

### 7d. A LAN player sees the server

Start WARNO on a PC on the same network, with each mod checked in the WebUI enabled in the game. Look for the server name in the multiplayer server browser and join. This proves the server registered with Eugen's master server and the map loads. It does not prove internet players can reach you.

### 7e. An internet player joins

Have someone outside your LAN find and join the server. Only this step proves the port forward, the WAN IP, and your ISP are all right. A TCP port checker website can confirm the TCP half of the forward; UDP cannot be checked that way.

When 7e works, the install goal in `docs/ROADMAP.md` is met. On Apply, Unraid writes `/boot/config/plugins/dockerMan/templates-user/my-<Name>.xml`, using the Name on the form. With Name left as `WARHOST`, that is the same file as the download. A different Name leaves the downloaded file in the dropdown as a second entry labeled **WARHOST**. Compare Unraid's saved copy with `templates/warhost.xml`; dockerMan's formatting is the one Community Applications expects.

## 8. Another server on the same host

Each server is its own container. Add another one from this same template. Do not use Unraid's reinstall action. Reinstall replaces the container you already have.

The container name, Game Port, and Settings Folder are unique. Set a different server name in each container's WebUI. The directory before `/settings` is that container's Game Port. The next container adds 1 to that port, in both the Game Port field and that directory.

| Field | First server | Second server |
| --- | --- | --- |
| Name | `WARHOST` | `WARHOST2` |
| Game Port | `10400` | `10401` |
| Settings Folder | `/mnt/user/appdata/warno/10400/settings` | `/mnt/user/appdata/warno/10401/settings` |
| Server name in the WebUI | `WARHOST - default server name` until you change it | a different name |

The map and workshop mods also belong to each container, so one server can run the Red Dragon example while another runs a base-game map. Public WAN IP, Eugen login, and Eugen dedicated key stay the same for up to five servers. A sixth container needs another login and key pair. Forward each Game Port to this Unraid server as TCP and UDP. Players join from the WARNO server browser by Server Name. They are not given a port to type.

On 2026-10-09 two containers on one Unraid host showed online with this pattern: Game Port `10400` at `/mnt/user/appdata/warno/10400/settings`, and Game Port `10401` at `/mnt/user/appdata/warno/10401/settings`, each with its own Server Name. A shared `/mnt/user/appdata/warno/settings` stopped the second container before that.

Every container uses the same image, stored once. The settings folder holds `login.ini`, `variables.ini`, and `params_for_ai.json`. The wrapper also creates `warhost.lock` there so two running containers cannot share the folder. If the image has no `flock` command, the start warns and continues. Do not copy WARNO or a Workshop folder into it. One pair runs five servers: fifteen servers need three pairs, fifty need ten, and one hundred needs twenty.

On start, the log names the next port and its settings folder. If the settings folder is already in use, or the game port is already taken, the container stops and the last log line says what to change.

## Troubleshooting

| Symptom | Likely cause | What to do |
| --- | --- | --- |
| Pull fails on Apply (`denied`, `unauthorized`, `not found`) | Package is private or image name is wrong | Step 2. |
| Container stops at once; log ends with `Set Public WAN IP.`, `Set your Eugen login.`, or `Set your Eugen dedicated key.` | A required field is empty | Edit the container, fill the field, Apply. |
| Container stops at once; log ends with `Eugen dedicated key must be at least 4 characters.` | The key is shorter than 4 characters | Paste the full key from Eugen's reply, and Apply. |
| Log ends with `Map must be a scenario ID, not the display name Jungle Law...` or `Set Map to a scenario ID...` | The container is still running `ghcr.io/suchamoneypit/warhost:latest`, whose entrypoint reads Map from the Docker form. The dev template does not send Map, so that image exits before the WebUI starts | Re-download the `dev` template after `ghcr.io/suchamoneypit/warhost:dev` exists, Apply, and confirm the repository is that `:dev` tag. The log should say `Wrote WARNO settings` or `Kept variables.ini`, then `WebUI listening on port`. |
| Log ends with `Workshop mod list must be empty, none, or Workshop ids such as 3811913066...` | `ModList` in `variables.ini` is not a list of Workshop ids | Open the WebUI and save the checklist, or fix that line. Ids are joined with hyphens. `/version` is a pin. |
| Log ends with `Workshop mod list must be empty, none, or look like 3811913066/27...` | The container still runs an image from before bare Workshop ids | On the **Docker** tab, check for updates and update the container. Until then, enter the pin from the README workshop table, such as `3811913066/27`. |
| Log ends with `Could not read Version for Workshop item ...` | That id has no saved `Version` in this settings folder, and Steam did not send its `Config.ini`. The `DepotDownloader:` lines above it give the reason: no connection to Steam, a wrong id, or a run longer than 300 seconds | Check the id against the number in the Workshop page URL, check the server's internet access, and start the container again. Or pin `id/version` with the `Version` from the mod's `Config.ini` (step 4). |
| Log contains `warning: Steam gave no update time for Workshop item ...` or `warning: Could not read Config.ini for Workshop item ...` | Steam gave no update time, or it reported an update and `Config.ini` could not be fetched. The `Version` saved at the last start was written, and the server starts | If players are refused, the author has likely published a new `Version`; restart the container once Steam answers. The `DepotDownloader:` lines above the second warning give the reason. |
| Log ends with `Official WARNO entrypoint was not found at /server/entrypoint2.sh.` | Eugen changed their image layout | Open a GitHub issue; the wrapper needs an update. |
| Log ends with `Game port 10400 is already in use` (the number will be the port you set) | That port is already listening on TCP, or bound on UDP, on the Unraid host. A port left in TIME_WAIT after a stop does not do this | Set Game Port to that number plus 1, forward the new port as TCP and UDP, and set Settings Folder to `/mnt/user/appdata/warno/10401/settings` when the new port is `10401`. Give this container a different server name in the WebUI. Players join by that name. |
| Container runs but the server never appears in anyone's browser | Outbound traffic to Eugen blocked; wrong login or key; wrong WAN IP | Check the lines after the wrapper's `Wrote WARNO settings` line for errors. Allow outbound to `178.32.126.73:10002`. Re-enter login and key from Eugen's reply. |
| LAN players join, internet players cannot | Router forward missing or only one protocol; WAN IP wrong or changed; carrier-grade NAT | Step 3. Forward TCP and UDP. Re-check the WAN IP. |
| Players are told a mod is missing or incompatible, and the log contains `warning: Workshop Mod List contains 3811913066/0` or `warning: Workshop Mod List contains 3811913066/15` | A pin in `variables.ini` is behind `Config.ini` `Version`. The server registers and `warno-server` logs nothing about the rejected join | Check that mod in the WebUI and save, then restart, so the next start reads the current `Version`. |
| A base-game server asks players for a Workshop mod, or the log contains `warning: Map ... is not a Red Dragon scenario` | `ModList` in `variables.ini` still lists a mod | Uncheck that mod in the WebUI and save, then restart. Changing the old Docker fields does not change the file. |
| Log contains `warning: Workshop Mod List is empty and Map ... is not a base-game scenario` | The map is not one of the base-game scenario IDs in the README, and `ModList` is empty. The server still starts | Check that map's pack in the WebUI and save, or choose a base-game map there, then restart. |
| Log contains `note: Workshop Mod Tags is ... and Workshop Mod List is empty` | The tags are in the file and label the server in the browser; they do not select modded content. | Save from the WebUI with no workshop mods checked if the server should not show mod icons. |
| Players are told a mod is missing or incompatible, and that warning is absent | They have not subscribed to and enabled the mod, a pin in the file is behind `Config.ini`, or the author published after this container started | Players: subscribe in Steam and enable the mod in WARNO's Mod Center. Host: save the mod again in the WebUI, which writes the bare id, then restart so the start reads the new `Version`. The client message does not appear in this log. |
| Hand edits to `variables.ini` disappear after a restart | A bare Workshop id was rewritten as `id/Version`, or a WebUI save replaced the file | Other lines stay. Set Write Config From Form to `false` to skip the version refresh. `false` leaves all three files and sets `login.ini` to mode `600`. |
| A WebUI save is not loaded yet | Save replaces `variables.ini` and does not signal the game | Restart that container to load it. |
| The browser says the Unraid address refused to connect when the Docker WebUI button is opened | Nothing is listening on the game port plus 1000. WebUI is `false`, or the container is still `ghcr.io/suchamoneypit/warhost:latest` from before this page was in the image. On 2026-10-11 that button opened port 11400 and Brave reported `10.0.1.105 refused to connect` while `warno-server` was already online | Set **WebUI** to `true` and Apply. The log must say `WebUI listening on port` followed by the game port plus 1000. For game port `10400` that is `11400`. If that line is absent and the log also never says `WebUI is off`, update the container after the image rebuild. A game port above 64535 does not print either line, because the page port would be above 65535. The game server can be healthy either way. |
| Log ends with `This settings folder is already used by a running container` | Two containers share one settings folder | The log names this Game Port's folder. If that folder is the one in use, it also names the folder for the port plus 1. Use the path that is not already taken. Do not copy WARNO or a Workshop folder into it. |
| A sixth container on the same login and key fails to come online | Eugen documents a limit of five servers per login and key pair; the exact error has not been observed. This wrapper does not count running servers | Stop one, or request another login and key pair. |
| Players on a new WARNO patch cannot join | The image is older than the game | The rebuild runs daily. On Unraid, check for updates on the Docker tab and update the container. |

## Not yet verified

These need a real Unraid install with a real key. They are listed so nobody mistakes this guide for a test record.

- A line-by-line check that Unraid 7 prefills every field as written here. The dropdown label **WARHOST** for `my-WARHOST.xml` was seen on 2026-10-09, and Key last 4 was absent after a fresh curl of `main`. A file named `warno-dedicated-server.xml` was reported to show that lowercase name.
- What a healthy `warno-server` prints after the wrapper's first log line, and how long the first start takes.
- Which sockets (TCP, UDP, or both) `warno-server` opens on the game port.
- That a container added from the current template keeps cleared workshop fields empty after Apply. Unraid's [Helpers.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/Helpers.php), read on 2026-10-10, fills a blank field from the template default, and both workshop defaults are now empty.
- Whether the server itself downloads Workshop item `3811913066`, or only tells joining clients to. Until that path is known, do not add a copy of the game for each container.
- A bare Workshop id on a running container. On 2026-10-10 the wrapper and DepotDownloader ran inside the unpacked `eugensystems/warno` filesystem and wrote `3811913066/27-3474588989/14` from Steam. No container has run the rebuilt image yet, and no player has joined through it.
- Whether the plain-paragraph Overview renders with paragraph breaks on this Unraid server. The template no longer contains `<br>` tags. Unraid's current [CreateDocker.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/CreateDocker.php), read on 2026-10-09, turns newlines in the basic Overview into line breaks. That has not been checked on a server after this wording change.
