# First install on Unraid 7.x

A step-by-step guide from nothing to a WARNO dedicated server that players can join. It is written for someone who has never installed a container outside Community Applications.

What this guide rests on, checked on 2026-10-09:

- Eugen's instructions on [Docker Hub](https://hub.docker.com/r/eugensystems/warno) (key request, settings files, host networking, TCP and UDP).
- The published image `ghcr.io/suchamoneypit/warno-unraid:latest`: readable without credentials, entrypoint `/server/entrypoint-unraid.sh`.
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

Both were confirmed on 2026-10-09; repeat the check if months have passed or you forked the repository.

- The template file must return `200`: <https://raw.githubusercontent.com/suchamoneypit/WARNO-Dedicated-Server-Unraid/main/templates/warno-dedicated-server.xml>
- The image must be pullable without logging in. Open <https://github.com/suchamoneypit/WARNO-Dedicated-Server-Unraid/pkgs/container/warno-unraid>; the package must be **Public**. From any Linux or macOS terminal, this must print `200`:

  ```sh
  TOKEN=$(curl -s "https://ghcr.io/token?scope=repository:suchamoneypit/warno-unraid:pull" | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
  curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.index.v1+json" \
    https://ghcr.io/v2/suchamoneypit/warno-unraid/manifests/latest
  ```

- The last **Rebuild WARNO image** run under the repository's **Actions** tab should be green. A red run means the published image is older than the repository; it still installs, but open an issue.

## 3. Network preparation

The container uses **host networking**, which Eugen recommends. That has three consequences:

1. Unraid shows **no port mapping** for this container. That is correct, not a missing field.
2. The game port must be free on the Unraid server itself. `10400` is this template's default; Eugen's docs use a placeholder. If something else on Unraid already uses `10400`, pick another port and use it everywhere below.
3. Every additional WARNO container needs a different port.

On your router, forward the game port **as both TCP and UDP** to your Unraid server's LAN IP. Eugen: "make sure you forward both UDP and the TCP to the exposed port because the server needs both." Give Unraid a fixed LAN IP (DHCP reservation) so the forward does not break.

Find your **public WAN IP** on the router's status page or any "what is my IP" site. The server advertises exactly the address you type in the form; it does not look it up. If your router's WAN address is in `100.64.0.0/10` (`100.64.` to `100.127.`), you are behind carrier-grade NAT; if it starts with `10.`, `172.16.` to `172.31.`, or `192.168.`, there is another router or NAT device upstream. In both cases a forward on your router alone will not reach you; forward on the upstream device too, or ask your ISP for a public address. If your public IP changes over time, you must update the field and restart the container.

The server also needs **outbound** internet. Eugen's start script in the image calls `warno-server` with `-ipmms 178.32.126.73 -portmms 10002`, so the server contacts Eugen's master server at that address. The image itself is small (about 80 MB) and contains no game data, so expect the first start to take longer than later ones. What it downloads, and where, has not been observed.

## 4. Decide the map and find a scenario ID

**Map** is a scenario ID, not a map name. Eugen's page lists base-game IDs such as `_2x2_Hesse_2vs2_CONQ`; those need no mod, so clear **Workshop Mod List** for them. For a Workshop map pack, the IDs are inside the mod's files, and the Workshop page does not publish them.

The template defaults to Jungle Law from the Red Dragon map pack: Map `RDPort_JungleLaw_2v2_CONQ`, Workshop Mod List `3811913066/0`. The full list of that pack's IDs is in `README.md`.

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
5. `Config.ini` in the mod root confirms the item ID (`ID = 3811913066`) and shows the mod's own `Version` number (`15` on 2026-10-09). Eugen says the version in `ModList` "is usually always 0"; this template uses `/0`. See troubleshooting if players report a mod mismatch.

Pick a size that fits the ID: the `2v2` in the ID means Max Players 4 and Team Size 2; `4v4` means 8 and 4; `10v10` means 20 and 10. All Red Dragon maps are Conquest, so Combat Rule stays `2`.

## 5. Put the template into Unraid

Unraid 6.10 removed the **Template Repositories** URL box from the Docker tab, so there is no place to paste a template URL in Unraid 7. Until this template is in Community Applications, use the flash drive:

1. In the Unraid web UI, open the terminal (the `>_` icon top right) and run:

   ```sh
   mkdir -p /boot/config/plugins/dockerMan/templates-user
   curl -fsSL -o /boot/config/plugins/dockerMan/templates-user/warno-dedicated-server.xml \
     https://raw.githubusercontent.com/suchamoneypit/WARNO-Dedicated-Server-Unraid/main/templates/warno-dedicated-server.xml
   ```

2. Go to **Docker → Add Container**. Open the **Template** dropdown at the top and pick the WARNO entry under **User templates**. Every field prefills.

Alternative: save the same file under `/boot/config/plugins/community.applications/private/suchamoneypit/` and install it from the **Apps** tab, where it appears under **Private**. Both routes were stated by the Community Applications author; neither has been executed for this repository yet.

## 6. Fill in the form

Click **Show more settings** to see the advanced fields. Leave defaults alone unless the table says otherwise.

| Field | Default | Enter |
| --- | --- | --- |
| Name | `WARNO-Dedicated-Server` | Keep, or any unique container name. |
| Network Type | `Host` | Keep. |
| Settings Folder | `/mnt/user/appdata/warno/settings` | Keep. Unraid creates it. One folder per server. |
| Eugen Login | empty | The login from Eugen's reply. |
| Eugen Dedicated Key | empty, masked | The key from Eugen's reply. |
| Public WAN IP | empty | Your public IP address from step 3. |
| Game Port | `10400` | Keep unless the port is taken. Must match the router forward. |
| Server Name | `WARNO Jungle Law 2v2` | What players see in the browser. No `=` sign. |
| Map | `RDPort_JungleLaw_2v2_CONQ` | A scenario ID from step 4. `Jungle Law` is rejected on purpose. |
| Max Players (advanced) | `4` | Match the map size. |
| Minimum Players (advanced) | `2` | Players needed before the countdown. Not above Max Players. |
| Team Size (advanced) | `2` | Match the map size. |
| Combat Rule (advanced) | `2` | `2` Conquest, `1` Destruction. |
| Workshop Mod List (advanced) | `3811913066/0` | Keep for Red Dragon maps. Clear for a base-game map. |
| Workshop Mod Tags (advanced) | `Maps-Scenarios` | Informational only. |
| Write Config From Form (advanced) | `true` | Keep. |

Click **Apply**. Unraid pulls the image and starts the container. A pull error here means Unraid could not fetch the image; the first troubleshooting row and step 2 cover the usual causes.

## 7. Confirm it works

Work through these in order. Each one proves something different.

### 7a. The container started

On the **Docker** tab the container shows as started. Click its icon → **Logs**. The first line from this wrapper is:

```text
Wrote WARNO settings for WARNO Jungle Law 2v2 on port 10400.
```

Anything after that line comes from Eugen's server. Nobody has recorded what a healthy `warno-server` prints; when you see it, add it to this file. If the container stopped **before** printing that line, the last log line is one of the wrapper's own error messages (first rows of the troubleshooting table). If it stopped **after** that line, the wrapper did its job and `warno-server` itself exited; read the lines after it and use the later rows.

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

When 7e works, the install goal in `docs/ROADMAP.md` is met. Unraid is expected to save its own copy of the template into `/boot/config/plugins/dockerMan/templates-user/` when you press Apply, beside the file you downloaded, so a second WARNO entry may appear in the Template dropdown afterwards. Compare Unraid's saved copy with `templates/warno-dedicated-server.xml`; dockerMan's formatting is the one Community Applications expects.

## Troubleshooting

| Symptom | Likely cause | What to do |
| --- | --- | --- |
| Pull fails on Apply (`denied`, `unauthorized`, `not found`) | Package is private or image name is wrong | Step 2. |
| Container stops at once; log ends with `Set Public WAN IP.`, `Set your Eugen login.`, `Set your Eugen dedicated key.`, or `Set Map to a scenario ID...` | A required field is empty | Edit the container, fill the field, Apply. |
| Log ends with `Map must be a scenario ID, not the display name Jungle Law...` or `Replace Map with a scenario ID...` | A map name or placeholder was entered | Step 4. |
| Log ends with `Workshop mod list must look like 3811913066/0...` | Mod list format | Use `id/version`, hyphen between mods, or clear it. |
| Log ends with `Official WARNO entrypoint was not found at /server/entrypoint2.sh.` | Eugen changed their image layout | Open a GitHub issue; the wrapper needs an update. |
| Log says a port or address is already in use | Host networking; something on Unraid uses the port | Change Game Port, forward the new port, Apply. |
| Container runs but the server never appears in anyone's browser | Outbound traffic to Eugen blocked; wrong login or key; wrong WAN IP | Check the lines after the wrapper's `Wrote WARNO settings` line for errors. Allow outbound to `178.32.126.73:10002`. Re-enter login and key from Eugen's reply. |
| LAN players join, internet players cannot | Router forward missing or only one protocol; WAN IP wrong or changed; carrier-grade NAT | Step 3. Forward TCP and UDP. Re-check the WAN IP. |
| Players are told a mod is missing or incompatible | They have not subscribed to and enabled item `3811913066`; or the mod version in `ModList` does not match | Players: subscribe in Steam, enable in WARNO's Mod Center. Host, if they already did: unverified, but the mod's `Config.ini` shows `Version = 15`; try `3811913066/15` in Workshop Mod List and report the result in an issue. |
| Hand edits to `variables.ini` disappear after a restart | Write Config From Form is `true` | Set it to `false`. All three files must then exist. |
| A sixth container on the same login and key fails to come online | Eugen documents a limit of five servers per login and key pair; the exact error has not been observed | Stop one, or request a second key. |
| Players on a new WARNO patch cannot join | The image is older than the game | The rebuild runs daily. On Unraid, check for updates on the Docker tab and update the container. |

## Not yet verified

These need a real Unraid install with a real key. They are listed so nobody mistakes this guide for a test record.

- That Unraid 7 shows the file from `templates-user` in the Template dropdown and prefills every field as written here.
- What a healthy `warno-server` prints after the wrapper's first log line, and how long the first start takes.
- Which sockets (TCP, UDP, or both) `warno-server` opens on the game port.
- Whether the server itself downloads Workshop item `3811913066`, or only tells joining clients to.
- Whether `ModList` wants `/0` or the mod's own `Version` number.
- Whether Unraid 7 strips the `<br>` tags in the template's Overview text.
