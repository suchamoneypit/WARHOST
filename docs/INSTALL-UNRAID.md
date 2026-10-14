# First install on Unraid 7.x

A step-by-step guide from nothing to a WARHOST container running a WARNO dedicated server that players can join. It is written for someone who has never installed a container outside Community Applications.

## 0. Checklist before you start

You need all of these.

| Item | How |
| --- | --- |
| Eugen dedicated-server login and key | Step 1. Allow for a reply delay; Eugen's page gives no turnaround time. |
| Your public WAN IP | Step 2. |
| Router port forward | Step 2. |
| An Unraid 7.x server with Docker enabled and the array started | Settings → Docker → Enable Docker: Yes. |
| A different map, if you do not want the seeded Hesse 2v2 | Step 3. The first start seeds `_2x2_Hesse_2vs2_CONQ`. Change it in the WebUI. |
| For players: WARNO on Steam and, for the Red Dragon maps, Workshop item `3811913066` subscribed and enabled in WARNO's Mod Center | The Workshop page says so; the server does not install the mod for them. |

## 1. Request the Eugen login and key

Eugen's Docker Hub page says: request access by emailing `eugsupport@eugensystems.com` and "provide the email you used to create your EugNet account. We will send you back a login and apikey pair." If you already have a dedicated key from another Eugen game, it works for WARNO and you do not need to write. One login and key pair can run at most five servers.

What you get back is a **login** and a **key**. Enter the login exactly as it appears in Eugen's reply; do not assume it is your email address. Keep both out of GitHub, screenshots, and chat. The only places they belong are the Unraid form and the `login.ini` file the container writes on your server.

## 2. Network preparation

The container uses **host networking**, which Eugen recommends. That has three consequences:

1. Unraid shows **no port mapping** for this container. That is correct, not a missing field.
2. The game port must be free on the Unraid server itself. `10400` is this template's default; Eugen's docs use a placeholder. If something else on Unraid already uses `10400`, pick another port and use it everywhere below.
3. Every additional container needs the previous game port plus 1. Forward each of those ports as TCP and UDP. Players join by the server name set in the WebUI.

On your router, forward the game port **as both TCP and UDP** to your Unraid server's LAN IP. Eugen: "make sure you forward both UDP and the TCP to the exposed port because the server needs both." Give Unraid a fixed LAN IP (DHCP reservation) so the forward does not break.

Find your **public WAN IP** on the router's status page or at <https://www.whatismyip.com/> from a device on that network. The Add Container form cannot look this up for you. The server advertises exactly the address you type; it does not look it up. If your router's WAN address is in `100.64.0.0/10` (`100.64.` to `100.127.`), you are behind carrier-grade NAT; if it starts with `10.`, `172.16.` to `172.31.`, or `192.168.`, there is another router or NAT device upstream. In both cases a forward on your router alone will not reach you; forward on the upstream device too, or ask your ISP for a public address. If your public IP changes over time, you must update the field and restart the container.

The server also needs **outbound** internet. Eugen's start script in the image calls `warno-server` with `-ipmms 178.32.126.73 -portmms 10002`, so the server contacts Eugen's master server at that address. The image contains no Steam library and is stored once no matter how many containers you add. With a bare Workshop id in `variables.ini`, each start also asks Steam whether that mod changed. Do not copy WARNO or a Workshop folder into each settings directory.

## 3. Decide the map and find a scenario ID

The map is a scenario ID, not a map name. Eugen's page lists base-game IDs such as `_2x2_Hesse_2vs2_CONQ`; those need no mod, so leave the WebUI workshop checklist clear for them. Steam Workshop Maps lists map packs; Full conversions and other mods, on the right, lists Galactic Divide, A World in Flames, and any id already in `variables.ini` that is not in either list. For a Workshop map pack, the IDs are inside the mod's files, and the Workshop page does not publish them.

The first start seeds the base-game map Hesse 2v2, `_2x2_Hesse_2vs2_CONQ`, with no workshop mods and the server name `WARHOST - default server name`. For the Red Dragon map pack, check `3811913066` in the WebUI and choose `RDPort_JungleLaw_2v2_CONQ`. Scenario IDs and workshop mods are in `README.md`. The procedure below finds IDs for a mod that is not listed there.

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
5. `Config.ini` in the mod root confirms the item ID and shows the mod's `Version`. Enter only the id in the WebUI. The next start reads the current `Version` from Steam and writes `id/Version`. A typed `id/Version` is a pin and is kept as typed.

Usual player counts for each size are in the README. Choosing a map in the WebUI fills max players, team size, and minimum players from that map, and those three can be edited before the save. Eugen does not lock the lobby to the size in the scenario ID. All Red Dragon maps are Conquest, so the combat rule stays `2` for them. WEST FULDA 1.0, Highway to Oslo, Ramstein Air Base, and Arsenal include Destruction scenarios. Helbe's skirmish files are Conquest. Combat Rule is `2` when the scenario ID contains `CONQ` or `Conquest`, and `1` when it contains `DEST` or `Destruction`. Oslo, Ramstein, and Arsenal use the full words `Conquest` and `Destruction`. For a scenario in the WebUI list, the combat rules menu offers only that rule, and a save with the other rule is rejected. A saved map that is not in the list still offers both.

## 4. Put the template into Unraid

WARHOST is listed in Community Applications. In the **Apps** tab, search for **WARHOST** and choose **Install**. The Add Container form opens with every field prefilled; continue with step 5. That installs the `main` template and `ghcr.io/suchamoneypit/warhost:latest`.

To install the `dev` template, or a template change before Community Applications picks it up, copy the XML onto the flash drive instead. Unraid 6.10 removed the **Template Repositories** URL box from the Docker tab, so Unraid 7 has no place to paste a template URL.

`sh scripts/print_template_fetch.sh`, run in a checkout of this repository, prints the command below. In the Unraid web UI, open the terminal (the `>_` icon top right) and paste it. Paste only the branch you are about to add. On Apply, Unraid writes `my-<Name>.xml` from the Name field. A clean-slate command for contributors is in `docs/AI-WORKFLOW.md`.

```sh
mkdir -p /boot/config/plugins/dockerMan/templates-user
curl -fsSL -o /boot/config/plugins/dockerMan/templates-user/my-WARHOST.xml \
  https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/templates/warhost.xml
```

The `dev` template is a separate download. It installs `ghcr.io/suchamoneypit/warhost:dev`. The `main` template installs `ghcr.io/suchamoneypit/warhost:latest`. Paste this instead of the `main` command when that is the container you are adding. Wait until **Rebuild WARHOST image** has published that tag, or Apply cannot pull it.

```sh
mkdir -p /boot/config/plugins/dockerMan/templates-user
curl -fsSL -o /boot/config/plugins/dockerMan/templates-user/my-WARHOST-dev.xml \
  https://raw.githubusercontent.com/suchamoneypit/WARHOST/dev/templates/warhost.xml
```

Go to **Docker → Add Container**. Open the **Template** dropdown at the top and pick **WARHOST** for the `main` download, or **WARHOST-dev** for the `dev` download, under **User templates**. Every field prefills. The dev entry's repository is `ghcr.io/suchamoneypit/warhost:dev`.

Unraid labels that menu from the filename, with `my-` removed. The `<Name>` in the XML is `WARHOST`. That string is the Docker container name and the dropdown title. If an earlier download is still in the folder, delete it:

```sh
rm -f /boot/config/plugins/dockerMan/templates-user/warno-dedicated-server.xml \
  /boot/config/plugins/dockerMan/templates-user/my-WARNO-Dedicated-Server.xml
```

Close Add Container before curling. Apply on a tab that is already open writes that tab back over the file. A download of `main` runs `ghcr.io/suchamoneypit/warhost:latest`. A download of `dev` runs `ghcr.io/suchamoneypit/warhost:dev`.

Another flash-drive route: `sh scripts/print_template_fetch.sh --private` prints the command that saves the file where the Apps tab looks for private templates. Paste that instead:

```sh
mkdir -p /boot/config/plugins/community.applications/private/suchamoneypit
curl -fsSL -o /boot/config/plugins/community.applications/private/suchamoneypit/warhost.xml \
  https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/templates/warhost.xml
```

This private download has not been tried on this repository. It is meant to appear in the **Apps** tab under **Private**.

## 5. Fill in the form

**Show more settings** holds Write Config From Form. The server name, map, player counts, combat rule, and workshop mods are set in the WebUI after the first start. Scenic view and tactical zones stay text; the published image does not include map pictures. Save and restart on that page restarts the dedicated server. If the page cannot restart the container, restart it in Unraid. A container added from an earlier template can still show lobby fields. The entrypoint ignores them. Leave defaults alone unless the table says otherwise. Scenario IDs are in the README.

| Field | Default | Enter |
| --- | --- | --- |
| Name | `WARHOST` | Keep for the first server. Each added container needs its own name. |
| Network Type | `Host` | Keep. |
| Settings Folder | `/mnt/user/appdata/warno/10400/settings` | Keep when Game Port stays `10400`. If step 2 replaced that port, put the replacement in this path. The next container uses this path with the port number plus 1, for example `/mnt/user/appdata/warno/10401/settings`. These are small ini files. Do not copy the game here. |
| Eugen Login | empty | The login from Eugen's reply. |
| Eugen Dedicated Key | empty | The key from Eugen's reply. Paste the whole key. The log shows only the last 4 characters. |
| Public WAN IP | empty | Your public IP address from step 2. |
| WebUI | `true` | Keep. Serves the lobby page at the game port plus 1000, so `10400` is `http://<this-unraid-host>:11400/`. Do not forward that port. Set the server name, map, and mods there. `false` leaves the WebUI button with nothing listening. If WebUI is true and 11400 is taken, the log says `warning: WebUI port 11400 is already in use. The game server will still start.` If WebUI is false, it says `WebUI is off. Nothing is listening on port 11400.` or `WebUI is off. Port 11400 is already in use.` The Docker WebUI button opens 11400, the first server only. |
| Game Port | `10400` | Keep for the first server. The next container uses this number plus 1. Forward each number as TCP and UDP. Players join by the server name set in the WebUI. You can change a port later by editing that container; the forward must use the same number. |
| Write Config From Form (Show more) | `true` | Keep. Rewrites `login.ini` each start, fills in missing lobby files, and refreshes a bare Workshop id to `id/Version`. `false` leaves the file contents in place and sets `login.ini` to mode 600. |

Click **Apply**. Unraid pulls the image and starts the container. A pull error here means Unraid could not fetch the image. The first troubleshooting row says what to check.

## 6. Confirm it works

Work through these in order. Each one proves something different.

### 6a. The container started

On the **Docker** tab the container shows as started. Click its icon → **Logs**. With a new settings folder the preset looks like this:

```text
Wrote WARNO settings for WARHOST - default server name on port 10400. Map _2x2_Hesse_2vs2_CONQ. Key last 4 XXXX.
Next container on this host: Game Port 10401, settings folder /mnt/user/appdata/warno/10401/settings, and a different server name in the WebUI.
WebUI listening on port 11400.
```

An existing `variables.ini` starts with `Kept variables.ini for` instead of `Wrote WARNO settings`. If the log shows `warning:`, use the troubleshooting table. Eugen's server prints after those wrapper lines. If the container stopped before `Wrote WARNO settings` or `Kept variables.ini`, the last log line is one of the wrapper's own error messages. If it stopped after Eugen's output begins, the wrapper did its job and `warno-server` itself exited.

### 6b. The settings files exist

From the Unraid terminal:

```sh
ls -la /mnt/user/appdata/warno/10400/settings/
grep -E '^(ServerName|Map|ModList) ' /mnt/user/appdata/warno/10400/settings/variables.ini
```

Expect `login.ini` at mode `-rw-------`. With WebUI left on, `variables.ini` and `params_for_ai.json` are `-rw-r--r--` so the page can read them. `Map = _2x2_Hesse_2vs2_CONQ` with no `ModList` line. A `.warhost-stage.*` directory should not remain after this start. `warhost.lock` is the wrapper's lock file. After a WebUI save that checks a workshop mod, and the restart that follows, `warhost-workshop-versions.txt` lists each bare id, Steam's update time, and the `Version` written. Do not display `login.ini` on a shared screen; it contains the key.

### 6c. The port is open on Unraid

Still in the Unraid terminal:

```sh
ss -lunp | grep 10400
ss -ltnp | grep 10400
```

With host networking the `warno-server` process appears directly in that list. Eugen says the server needs both protocols.

### 6d. A LAN player sees the server

Start WARNO on a PC on the same network, with each mod checked in the WebUI enabled in the game. Look for the server name in the multiplayer server browser and join. This proves the server registered with Eugen's master server and the map loads. It does not prove internet players can reach you.

### 6e. An internet player joins

Have someone outside your LAN find and join the server. Only this step proves the port forward, the WAN IP, and your ISP are all right. A TCP port checker website can confirm the TCP half of the forward; UDP cannot be checked that way.

When an internet player can join, the server is installed. On Apply, Unraid writes `/boot/config/plugins/dockerMan/templates-user/my-<Name>.xml` from the Name on the form. With Name left as `WARHOST`, that replaces the downloaded file. A different Name leaves the download in the dropdown as a second entry labeled **WARHOST**.

## 7. Another server on the same host

Each server is its own container. Add another one from this same template. Do not use Unraid's reinstall action. Reinstall replaces the container you already have.

The container name, Game Port, and Settings Folder are unique. Set a different server name in each container's WebUI. The directory before `/settings` is that container's Game Port. The next container adds 1 to that port, in both the Game Port field and that directory.

| Field | First server | Second server |
| --- | --- | --- |
| Name | `WARHOST` | `WARHOST2` |
| Game Port | `10400` | `10401` |
| Settings Folder | `/mnt/user/appdata/warno/10400/settings` | `/mnt/user/appdata/warno/10401/settings` |
| Server name in the WebUI | `WARHOST - default server name` until you change it | a different name |

The map and workshop mods also belong to each container, so one server can run the Red Dragon example while another runs a base-game map. Public WAN IP, Eugen login, and Eugen dedicated key stay the same for up to five servers. A sixth container needs another login and key pair. Forward each Game Port to this Unraid server as TCP and UDP. Players join from the WARNO server browser by Server Name. They are not given a port to type.

Every container uses the same image, stored once. The settings folder holds `login.ini`, `variables.ini`, and `params_for_ai.json`. The wrapper also creates `warhost.lock` there so two running containers cannot share the folder. Do not copy WARNO or a Workshop folder into it. One pair runs five servers.

On start, the log names the next port and its settings folder. If the settings folder is already in use, or the game port is already taken, the container stops and the last log line says what to change.

## Troubleshooting

| Symptom | Likely cause | What to do |
| --- | --- | --- |
| Pull fails on Apply (`denied`, `unauthorized`, `not found`) | Package is private or image name is wrong | Run the check under this table. |
| Container stops at once; log ends with `Set Public WAN IP.`, `Set your Eugen login.`, or `Set your Eugen dedicated key.` | A required field is empty | Edit the container, fill the field, Apply. |
| Container stops at once; log ends with `Eugen dedicated key must be at least 4 characters.` | The key is shorter than 4 characters | Paste the full key from Eugen's reply, and Apply. |
| Log ends with `Map must be a scenario ID, not the display name Jungle Law...` or `Set Map to a scenario ID...` | The container is still running a `ghcr.io/suchamoneypit/warhost:latest` image from before the WebUI publish. That entrypoint reads Map from the Docker form. The current template does not send Map, so that image exits before the WebUI starts | Update the container after **Rebuild WARHOST image** finishes, and confirm the repository is `ghcr.io/suchamoneypit/warhost:latest`, or `:dev` when this container was added from the dev template. The log should say `Wrote WARNO settings` or `Kept variables.ini`, then `WebUI listening on port`. |
| Log ends with `Workshop mod list must be empty or Workshop ids such as 3811913066...` | `ModList` in `variables.ini` is not a list of Workshop ids | Open the WebUI and save the checklist, or fix that line. Ids are joined with hyphens. `/Version` is a pin. |
| Log ends with `Workshop mod list must be empty, none, or look like 3811913066/27...` | The container still runs an image from before bare Workshop ids | On the **Docker** tab, check for updates and update the container. Until then, enter the pin from the README workshop table, such as `3811913066/27`. |
| Log ends with `Could not read Version for Workshop item ...` | That id has no saved `Version` in this settings folder, and Steam did not send its `Config.ini`. The `DepotDownloader:` lines above it give the reason: no connection to Steam, a wrong id, or a run longer than 300 seconds | Check the id against the number in the Workshop page URL, check the server's internet access, and start the container again. Or pin `id/Version` with the `Version` from the mod's `Config.ini` (step 3). |
| Log contains `warning: Steam gave no update time for Workshop item ...` or `warning: Could not read Config.ini for Workshop item ...` | Steam gave no update time, or it reported an update and `Config.ini` could not be fetched. The `Version` saved at the last start was written, and the server starts | If players are refused, the author has likely published a new `Version`; restart the container once Steam answers. The `DepotDownloader:` lines above the second warning give the reason. |
| Log ends with `Eugen's start script was not found at /server/entrypoint2.sh.` | Eugen changed their image layout | Update the container. If it still stops, open a GitHub issue. |
| Log ends with `Game port 10400 is already in use` (the number will be the port you set) | That port is already listening on TCP, or bound on UDP, on the Unraid host. A port left in TIME_WAIT after a stop does not do this | Set Game Port to that number plus 1, forward the new port as TCP and UDP, and set Settings Folder to `/mnt/user/appdata/warno/10401/settings` when the new port is `10401`. Give this container a different server name in the WebUI. Players join by that name. |
| Container runs but the server never appears in anyone's browser | Outbound traffic to Eugen blocked; wrong login or key; wrong WAN IP | Check the lines after the wrapper's `Wrote WARNO settings` line for errors. Allow outbound to `178.32.126.73:10002`. Re-enter login and key from Eugen's reply. |
| LAN players join, internet players cannot | Router forward missing or only one protocol; WAN IP wrong or changed; carrier-grade NAT | Step 2. Forward TCP and UDP. Re-check the WAN IP. |
| Players are told a mod is missing or incompatible, and the log contains `warning: Workshop Mod List contains 3811913066/0` or `warning: Workshop Mod List contains 3811913066/15` | A pin in `variables.ini` is behind `Config.ini` `Version`. The server registers and `warno-server` logs nothing about the rejected join | Check that mod in the WebUI and save, then restart, so the next start reads the current `Version`. |
| A base-game server asks players for a Workshop mod, or the log contains `warning: Map ... is not a Red Dragon scenario` | `ModList` in `variables.ini` still lists a mod | Uncheck that mod in the WebUI and save, then restart. Changing the old Docker fields does not change the file. |
| Log contains `warning: Workshop Mod List is empty and Map ... is not a base-game scenario` | The map is not one of the base-game scenario IDs in the README, and `ModList` is empty. The server still starts | Check that map's pack in the WebUI and save, or choose a base-game map there, then restart. |
| Log contains `note: Workshop Mod Tags is ... and Workshop Mod List is empty` | The tags are in the file and label the server in the browser; they do not select modded content. | Save from the WebUI with no workshop mods checked if the server should not show mod icons. |
| Players are told a mod is missing or incompatible, and that warning is absent | They have not subscribed to and enabled the mod, a pin in the file is behind `Config.ini`, or the author published after this container started | Players: subscribe in Steam and enable the mod in WARNO's Mod Center. Host: save the mod again in the WebUI, which writes the bare id, then restart so the start reads the new `Version`. The client message does not appear in this log. |
| Hand edits to `variables.ini` disappear after a restart | A bare Workshop id was rewritten as `id/Version`, or a WebUI save replaced the file | Other lines stay. Set Write Config From Form to `false` to skip the version refresh. `false` leaves all three files and sets `login.ini` to mode `600`. |
| A WebUI save is not loaded yet | Save replaces `variables.ini` and leaves the current match running | Use Save and restart on that page. If it says the page cannot restart the container, restart that container in Unraid. |
| The browser says the Unraid address refused to connect when the Docker WebUI button is opened | Nothing is listening on the game port plus 1000. WebUI is `false`, or the container is an image from before the page was published | Set **WebUI** to `true` and Apply. The log must say `WebUI listening on port` followed by the game port plus 1000. For game port `10400` that is `11400`. If that line is absent and the log also never says `WebUI is off`, update the container. |
| Log ends with `This settings folder is already used by a running container` | Two containers share one settings folder | The log names this Game Port's folder. If that folder is the one in use, it also names the folder for the port plus 1. Use the path that is not already taken. Do not copy WARNO or a Workshop folder into it. |
| A sixth container on the same login and key fails to come online | Eugen documents a limit of five servers per login and key pair; the exact error has not been observed. This wrapper does not count running servers | Stop one, or request another login and key pair. |
| Players on a new WARNO patch cannot join | The image is older than the game | The rebuild runs daily. On Unraid, check for updates on the Docker tab and update the container. |

### Pull fails on Apply

The package must be public. Open <https://github.com/suchamoneypit/WARHOST/pkgs/container/warhost>. From any Linux or macOS terminal, this must print `200`. For a `dev` template, change `latest` to `dev` in the last URL.

```sh
TOKEN=$(curl -s "https://ghcr.io/token?scope=repository:suchamoneypit/warhost:pull" | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.index.v1+json" \
  https://ghcr.io/v2/suchamoneypit/warhost/manifests/latest
```

The template file must return `200`: <https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/templates/warhost.xml>. The template ReadMe is https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/README.md and the template License is https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/LICENSE. A red **Rebuild WARHOST image** run is a failed build, which leaves the previous image. Open an issue.

## Not yet verified

The maintainer's install confirmed the container, the key, and the Hesse map. These items were not recorded and still need a real Unraid install with a real key.

- A line-by-line check that Unraid 7 prefills every field as written here. The dropdown label **WARHOST** for `my-WARHOST.xml` was seen on 2026-10-09, and Key last 4 was absent after a fresh curl of `main`. A file named `warno-dedicated-server.xml` was reported to show that lowercase name.
- What a healthy `warno-server` prints after the wrapper's first log line, and how long the first start takes.
- Which sockets (TCP, UDP, or both) `warno-server` opens on the game port.
- That a container added from the current template keeps cleared workshop fields empty after Apply. Unraid's [Helpers.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/Helpers.php), read on 2026-10-10, fills a blank field from the template default, and both workshop defaults are now empty.
- Whether the server itself downloads Workshop item `3811913066`, or only tells joining clients to. Until that path is known, do not add a copy of the game for each container.
- A bare Workshop id on a running container. On 2026-10-10 the wrapper and DepotDownloader ran inside the unpacked `eugensystems/warno` filesystem and wrote `3811913066/27-3474588989/14` from Steam. No container has run the rebuilt image yet, and no player has joined through it.
- Whether the plain-paragraph Overview renders with paragraph breaks on this Unraid server. The template no longer contains `<br>` tags. Unraid's current [CreateDocker.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/CreateDocker.php), read on 2026-10-09, turns newlines in the basic Overview into line breaks. That has not been checked on a server after this wording change.
- The private Apps-tab download (`sh scripts/print_template_fetch.sh --private`) has not been tried on this repository.
