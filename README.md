# WARNO dedicated server for Unraid

Unraid template for one [WARNO](https://store.steampowered.com/app/1611600/WARNO/) dedicated server per container. The install form takes your Eugen login and dedicated key and writes `login.ini`, `variables.ini`, and `params_for_ai.json`. The container then runs the entrypoint from the official `eugensystems/warno` image.

The preset is a 2v2 Conquest server for Jungle Law in the [Red Dragon map pack](https://steamcommunity.com/sharedfiles/filedetails/?id=3811913066) (workshop item `3811913066`).

## Before you install

Email `eugsupport@eugensystems.com` and ask for a dedicated-server login and key. Use the email on your EugNet account. Eugen answers manually, and one login/key pair can run five servers.

Joining players do not use that key. They need WARNO, and for this preset they subscribe to workshop item `3811913066` and enable it in WARNO's mod center.

On your router, forward the game port as both TCP and UDP to the Unraid server. The container uses host networking, so Unraid does not show a Docker port mapping. The server also needs outbound internet access so it can reach Eugen.

## Install

Community Apps listing comes after this template has been tested on a running server. Until then, add the container in Unraid with **Docker**, **Add Container**, and a template URL of:

```text
https://raw.githubusercontent.com/suchamoneypit/Warno-Dedicated-Server-Unraid/main/templates/warno-dedicated-server.xml
```

The image is `ghcr.io/suchamoneypit/warno-unraid:latest`. It does not exist until the GitHub Action has built it. See [Publishing the image](#publishing-the-image).

Fill in:

| Field | What to enter |
| --- | --- |
| Eugen Login | The login Eugen sent you |
| Eugen Dedicated Key | The key Eugen sent with that login |
| Public WAN IP | The public address players connect to |
| Game Port | `10400`, or another free port |
| Server Name | The name in the server browser |
| Map | The Jungle Law scenario ID from the workshop files |

Advanced fields are already set for a 2v2 Conquest match on the Red Dragon map pack: 4 players, 2 per team, combat rule `2`, mod `3811913066/0`.

### Jungle Law scenario ID

The workshop page shows the name Jungle Law. The server needs the scenario ID stored inside the mod. Subscribe on a PC, wait for Steam to finish the download (about 9.3 GB), and look in:

```text
steamapps/workshop/content/1611600/3811913066
```

Put that scenario ID in **Map**. `Jungle Law` and `YOUR_JUNGLE_LAW_SCENARIO_ID` are rejected. Vanilla map IDs in Eugen's documentation look like `_3x3_Airport_10vs10_CONQ`.

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

Questions and problems go to [GitHub issues](https://github.com/suchamoneypit/Warno-Dedicated-Server-Unraid/issues). Leave the Eugen key out of the issue.
