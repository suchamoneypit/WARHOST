# First install on Unraid 7.x

WARNO was a game made in France, but WARHOST was created in the United States.

A step-by-step guide from nothing to a WARHOST container running a WARNO dedicated server that players can join. It is written for someone who has never installed a container outside Community Applications.

What this guide rests on, checked on 2026-10-09:

- Eugen's instructions on [Docker Hub](https://hub.docker.com/r/eugensystems/warno) (key request, settings files, host networking, TCP and UDP).
- The image the template installs, `ghcr.io/suchamoneypit/warhost:latest`, after **Rebuild WARHOST image** has published it. Entrypoint `/server/entrypoint-unraid.sh`.
- Unraid's [container management docs](https://docs.unraid.net/unraid-os/manual/docker-management/) and the Community Applications author's statement that Unraid 6.10 [removed the Template Repositories field](https://forums.unraid.net/topic/112170-allow-template-repositories-to-be-hosted-from-other-sources/).
- The Red Dragon map pack files on a PC subscribed to Steam Workshop item `3811913066`.

What it does not rest on: nobody has yet run this template on an Unraid server and recorded the result. Steps 5 to 7 describe what should happen; the "Not yet verified" list at the end says what still needs that first real run. If you complete it, record what you saw in `docs/ROADMAP.md`.

## 0. Checklist before you start

You need all of these. Items marked **you** cannot be done by anyone else.

| Item | How |
| --- | --- |
| **you** Eugen dedicated-server login and key | Step 1. Allow for a reply delay; Eugen's page gives no turnaround time. |
| **you** Your public WAN IP | Step 3. |
| **you** Router port forward | Step 3. |
| An Unraid 7.x server with Docker enabled and the array started | Settings → Docker → Enable Docker: Yes. |
| The scenario ID of the map you want | Step 4. The default `RDPort_JungleLaw_2v2_CONQ` is already filled in. |
| For players: WARNO on Steam and, for the Red Dragon maps, Workshop item `3811913066` subscribed and enabled in WARNO's Mod Center | The Workshop page says so; the server does not install the mod for them. |

## 1. Request the Eugen login and key

Eugen's Docker Hub page says: request access by emailing `eugsupport@eugensystems.com` and "provide the email you used to create your EugNet account. We will send you back a login and apikey pair." If you already have a dedicated key from another Eugen game, it works for WARNO and you do not need to write. One login and key pair can run at most five servers.

What you get back is a **login** and a **key**. Enter the login exactly as it appears in Eugen's reply; do not assume it is your email address. Keep both out of GitHub, screenshots, and chat. The only places they belong are the Unraid form and the `login.ini` file the container writes on your server.

## 2. Confirm the image and template are published

The image to confirm is `ghcr.io/suchamoneypit/warhost:latest`. The repository is `WARHOST` (`https://github.com/suchamoneypit/WARNO-Dedicated-Server-Unraid` returned HTTP 301 to that name on 2026-10-09). Repeat the checks below if months have passed or you forked the repository.

- The template file must return `200`: <https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/templates/warhost.xml>. GitHub redirects the old repository URL. It does not redirect the old template filename.
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
3. Every additional WARHOST container needs a different port.

On your router, forward the game port **as both TCP and UDP** to your Unraid server's LAN IP. Eugen: "make sure you forward both UDP and the TCP to the exposed port because the server needs both." Give Unraid a fixed LAN IP (DHCP reservation) so the forward does not break.

Find your **public WAN IP** on the router's status page or at <https://www.whatismyip.com/> from a device on that network. The Add Container form cannot look this up for you. The server advertises exactly the address you type; it does not look it up. If your router's WAN address is in `100.64.0.0/10` (`100.64.` to `100.127.`), you are behind carrier-grade NAT; if it starts with `10.`, `172.16.` to `172.31.`, or `192.168.`, there is another router or NAT device upstream. In both cases a forward on your router alone will not reach you; forward on the upstream device too, or ask your ISP for a public address. If your public IP changes over time, you must update the field and restart the container.

The server also needs **outbound** internet. Eugen's start script in the image calls `warno-server` with `-ipmms 178.32.126.73 -portmms 10002`, so the server contacts Eugen's master server at that address. The image itself is small (about 80 MB) and contains no game data, so expect the first start to take longer than later ones. What it downloads, and where, has not been observed.

## 4. Decide the map and find a scenario ID

**Map** is a scenario ID, not a map name. Eugen's page lists base-game IDs such as `_2x2_Hesse_2vs2_CONQ`; those need no mod, so clear **Workshop Mod List** for them. For a Workshop map pack, the IDs are inside the mod's files, and the Workshop page does not publish them.

The template defaults to Jungle Law from the Red Dragon map pack: Map `RDPort_JungleLaw_2v2_CONQ`, Workshop Mod List `3811913066/15`. Base-game IDs, that pack's IDs, and the named workshop mods are in `README.md`. Galactic Divide (`3595948209`) and A World in Flames (`3388575848`) are not maps, so **Map** stays a scenario ID. Their pages, read on 2026-10-09, do not publish a `Config.ini` `Version`. Tag words are in the README: Galactic Divide is `Gameplay-Interface-Sound-Scenarios-Maps`, and A World in Flames is `Gameplay-Interface`, or `Gameplay-Interface-Maps-Scenarios` when a map pack is also required. WEST FULDA 1.0 (`3363584349`), Highway to Oslo (`3474588989`), Ramstein Air Base (`3705706772`), Arsenal (`3415339374`), and Helbe (`3762638679`) do not publish scenario IDs. Use the procedure below after you subscribe.

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
5. `Config.ini` in the mod root confirms the item ID (`ID = 3811913066`) and shows the mod's own `Version` number (`15` on 2026-10-09). The comment on that line says to increment it when an update is incompatible with the current version. **Workshop Mod List** must use that number, so the preset is `3811913066/15`. Eugen's page says the version in `ModList` "is usually always 0"; `/0` lets this server register and then the client rejects the join. If the author increments `Version`, change the field to the new number.

Usual Max Players and Team Size for each size are in the README. Eugen does not lock the lobby to the size in the scenario ID. All Red Dragon maps are Conquest, so Combat Rule stays `2` for them. WEST FULDA 1.0, Highway to Oslo, Ramstein Air Base, and Arsenal list both Conquest and Destruction: use `2` when the scenario ID contains `CONQ`, and `1` when it contains `DEST`. Helbe's page lists Conquest only, so leave Combat Rule at `2` for Helbe.

## 5. Put the template into Unraid

Unraid 6.10 removed the **Template Repositories** URL box from the Docker tab, so there is no place to paste a template URL in Unraid 7. Until this template is in Community Applications, copy it onto the flash drive.

`sh scripts/print_template_fetch.sh`, run in a checkout of this repository, prints the command below. `/unraid-template-installscript` prints the same thing. In the Unraid web UI, open the terminal (the `>_` icon top right) and paste it:

```sh
mkdir -p /boot/config/plugins/dockerMan/templates-user
curl -fsSL -o /boot/config/plugins/dockerMan/templates-user/my-WARHOST.xml \
  https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/templates/warhost.xml
```

Go to **Docker → Add Container**. Open the **Template** dropdown at the top and pick **WARHOST** under **User templates**. Every field prefills.

Unraid labels that menu from the filename, with `my-` removed ([CreateDocker.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/CreateDocker.php), read 2026-10-09). The `<Name>` in the XML is `WARHOST`. That string is the Docker container name. It cannot contain spaces, so the Apps and dropdown title is `WARHOST`, and WARNO stays in the overview. Extra search terms are `WARNO WARNO server dedicated server game server mods modded`. If an earlier download is still in the folder, delete it:

```sh
rm -f /boot/config/plugins/dockerMan/templates-user/warno-dedicated-server.xml \
  /boot/config/plugins/dockerMan/templates-user/my-WARNO-Dedicated-Server.xml
```

The filename matches what Unraid writes on Apply (`my-<Name>.xml`, case preserved, in [DockerClient.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/DockerClient.php) `getUserTemplatePath`). `my-WARHOST.xml` has not been tried on a server yet. A file named `warno-dedicated-server.xml` was reported to show that lowercase name.

Alternative, still until Community Applications lists it: `sh scripts/print_template_fetch.sh --private` prints the command that saves the file where the Apps tab looks for private templates. Paste that instead:

```sh
mkdir -p /boot/config/plugins/community.applications/private/suchamoneypit
curl -fsSL -o /boot/config/plugins/community.applications/private/suchamoneypit/warhost.xml \
  https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/templates/warhost.xml
```

It then appears in the **Apps** tab under **Private**. The user-template download was tried with the lowercase filename, and the dropdown showed that name. The private-folder route has not been executed for this repository.

## 6. Fill in the form

Login from Eugen's reply, exactly as written. Not your Steam name; this login and the key are a matching pair good for five containers.

Max Players, Minimum Players, Team Size, and Combat Rule are on the main form. Click **Show more settings** for the map and the workshop mods. Leave defaults alone unless the table says otherwise. Scenario IDs are in the README, not on the form.

| Field | Default | Enter |
| --- | --- | --- |
| Name | `WARHOST` | Keep, or any unique container name. The settings folder stays `/mnt/user/appdata/warno/settings`. |
| Network Type | `Host` | Keep. |
| Settings Folder | `/mnt/user/appdata/warno/settings` | Keep. Unraid creates it. One folder per server. |
| Eugen Login | empty | The login from Eugen's reply. |
| Eugen Dedicated Key | empty, masked | The key from Eugen's reply. |
| Key last 4 | empty | The last 4 characters of that key. Shown in clear text. Must match when Write Config From Form is true. |
| Public WAN IP | empty | Your public IP address from step 3. |
| Game Port | `10400` | Keep unless the port is taken. You can change it later by editing the container; the router forward must use the same number, TCP and UDP. |
| Server Name | `WARNO Jungle Law 2v2` | What players see in the browser. No `=` sign. |
| Max Players | `4` | Total slots. Preset 4 for this 2v2. Usual sizes are in the README. Not locked to the map. |
| Minimum Players | `2` | Players needed before the countdown. Not above Max Players. |
| Team Size | `2` | Slots on one side. Usually half of Max Players. |
| Combat Rule | `2` | `2` Conquest, `1` Destruction. |
| Write Config From Form (Show more) | `true` | Keep. |
| Workshop Mod Tags (Show more) | `Maps-Scenarios` | Browser icons only. It does not download mods. Leave this for the Red Dragon pack. A conversion uses the tag string in step 4. |
| Workshop Mod List (Show more) | `3811913066/15` | Keep for Red Dragon maps unless `Config.ini` `Version` has changed. Clear for a base-game map with no workshop mod. Named mods are in the README. |
| Map (Show more) | `RDPort_JungleLaw_2v2_CONQ` | A scenario ID from step 4. `Jungle Law` is rejected on purpose. Known IDs are in the README. |

Click **Apply**. Unraid pulls the image and starts the container. A pull error here means Unraid could not fetch the image; the first troubleshooting row and step 2 cover the usual causes.

## 7. Confirm it works

Work through these in order. Each one proves something different.

### 7a. The container started

On the **Docker** tab the container shows as started. Click its icon → **Logs**. The first wrapper line is `Wrote WARNO settings for WARNO Jungle Law 2v2 on port 10400. Map RDPort_JungleLaw_2v2_CONQ. ModList 3811913066/15. Key last 4` and the last 4 characters of the key. The wrapper then prints the Config.ini comparison line, and `warning: Workshop Mod List contains 3811913066/0` when that pair is set, before Eugen's output.

```text
Wrote WARNO settings for WARNO Jungle Law 2v2 on port 10400. Map RDPort_JungleLaw_2v2_CONQ. ModList 3811913066/15. Key last 4 XXXX.
Clients compare each Workshop id/version with Version in that mod's Config.ini. The client message "At least one mod version doesnt match" does not appear in this log.
```

Eugen's server prints after those wrapper lines. Nobody has recorded the full healthy `warno-server` log; when you see it, add it to this file. If the container stopped **before** printing that first line, the last log line is one of the wrapper's own error messages (first rows of the troubleshooting table). If it stopped **after** Eugen's output begins, the wrapper did its job and `warno-server` itself exited; read the lines after it and use the later rows.

### 7b. The settings files exist

From the Unraid terminal:

```sh
ls -l /mnt/user/appdata/warno/settings/
grep -E '^(ServerName|Map|ModList) ' /mnt/user/appdata/warno/settings/variables.ini
```

Expect `login.ini`, `variables.ini`, and `params_for_ai.json` with mode `-rw-------`, and `Map = RDPort_JungleLaw_2v2_CONQ`. Do not display `login.ini` on a shared screen; it contains the key.

### 7c. The port is open on Unraid

Still in the Unraid terminal:

```sh
ss -lunp | grep 10400
ss -ltnp | grep 10400
```

With host networking the `warno-server` process appears directly in that list. Eugen says the server needs both protocols; which sockets it actually opens has not been recorded. Note what you see.

### 7d. A LAN player sees the server

Start WARNO on a PC on the same network with the Workshop mod enabled. Look for the Server Name in the multiplayer server browser and join. This proves the server registered with Eugen's master server and the map loads. It does not prove internet players can reach you.

### 7e. An internet player joins

Have someone outside your LAN find and join the server. Only this step proves the port forward, the WAN IP, and your ISP are all right. A TCP port checker website can confirm the TCP half of the forward; UDP cannot be checked that way.

When 7e works, the install goal in `docs/ROADMAP.md` is met. On Apply, Unraid writes `/boot/config/plugins/dockerMan/templates-user/my-<Name>.xml`, using the Name on the form. With Name left as `WARHOST`, that is the same file as the download. A different Name leaves the downloaded file in the dropdown as a second entry labeled **WARHOST**. Compare Unraid's saved copy with `templates/warhost.xml`; dockerMan's formatting is the one Community Applications expects.

## Troubleshooting

| Symptom | Likely cause | What to do |
| --- | --- | --- |
| Pull fails on Apply (`denied`, `unauthorized`, `not found`) | Package is private or image name is wrong | Step 2. |
| Container stops at once; log ends with `Set Public WAN IP.`, `Set your Eugen login.`, `Set your Eugen dedicated key.`, or `Set Map to a scenario ID...` | A required field is empty | Edit the container, fill the field, Apply. |
| Container stops at once; log ends with `Set Key last 4 to the last 4 characters of the Eugen dedicated key.`, `Key last 4 does not match the Eugen dedicated key.`, or `Eugen dedicated key must be at least 4 characters.` | Key last 4 is empty or does not match, or the key is shorter than 4 characters | Type the last 4 characters of the dedicated key into Key last 4, and Apply. |
| Log ends with `Map must be a scenario ID, not the display name Jungle Law...` or `Replace Map with a scenario ID...` | A map name or placeholder was entered | Step 4. |
| Log ends with `Workshop mod list must look like 3811913066/15...` | Mod list format | Use `id/version`, hyphen between mods, or clear it. |
| Log ends with `Official WARNO entrypoint was not found at /server/entrypoint2.sh.` | Eugen changed their image layout | Open a GitHub issue; the wrapper needs an update. |
| Log says a port or address is already in use | Host networking; something on Unraid uses the port | Change Game Port, forward the new port, Apply. |
| Container runs but the server never appears in anyone's browser | Outbound traffic to Eugen blocked; wrong login or key; wrong WAN IP | Check the lines after the wrapper's `Wrote WARNO settings` line for errors. Allow outbound to `178.32.126.73:10002`. Re-enter login and key from Eugen's reply. |
| LAN players join, internet players cannot | Router forward missing or only one protocol; WAN IP wrong or changed; carrier-grade NAT | Step 3. Forward TCP and UDP. Re-check the WAN IP. |
| Players are told a mod is missing or incompatible, and the log contains `warning: Workshop Mod List contains 3811913066/0` | The field is still the old preset. The server registers and `warno-server` logs nothing about the rejected join | Set **Workshop Mod List** to `3811913066/15`, or to the `Version` line in the mod's `Config.ini` if the author has incremented it, and Apply. |
| Players are told a mod is missing or incompatible, and that warning is absent | They have not subscribed to and enabled the mod, or `Version` in `Config.ini` has changed | Players: subscribe in Steam and enable the mod in WARNO's Mod Center. Host: set **Workshop Mod List** to the `Version` line in `Config.ini`. The client message does not appear in this log. |
| Hand edits to `variables.ini` disappear after a restart | Write Config From Form is `true` | Set it to `false`. All three files must then exist. |
| A sixth container on the same login and key fails to come online | Eugen documents a limit of five servers per login and key pair; the exact error has not been observed | Stop one, or request a second key. |
| Players on a new WARNO patch cannot join | The image is older than the game | The rebuild runs daily. On Unraid, check for updates on the Docker tab and update the container. |

## Not yet verified

These need a real Unraid install with a real key. They are listed so nobody mistakes this guide for a test record.

- That Unraid 7 shows `my-WARHOST.xml` in the Template dropdown as **WARHOST** and prefills every field as written here. A file named `warno-dedicated-server.xml` was reported to show that lowercase name. `my-WARHOST.xml` and the prefill have not been recorded.
- What a healthy `warno-server` prints after the wrapper's first log line, and how long the first start takes.
- Which sockets (TCP, UDP, or both) `warno-server` opens on the game port.
- Whether the server itself downloads Workshop item `3811913066`, or only tells joining clients to.
- Whether the plain-paragraph Overview renders with paragraph breaks on this Unraid server. The template no longer contains `<br>` tags. Unraid's current [CreateDocker.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/CreateDocker.php), read on 2026-10-09, turns newlines in the basic Overview into line breaks. That has not been checked on a server after this wording change.
