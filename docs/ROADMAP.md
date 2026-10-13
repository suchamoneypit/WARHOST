# Roadmap

Goals and known issues, last updated 2026-10-13.

## Current goals

None recorded. Both earlier goals are done, as the maintainer reported on 2026-10-13:

- The Unraid install test: the container stays up, the dedicated key exists only in that server's settings files, and the running scenario is the preset Hesse map.
- The Community Applications submission: the listing is published.

## Known issues

- Whether the dedicated server downloads workshop item `3811913066` by itself has not been observed. Eugen's docs only describe the client download prompt: https://hub.docker.com/r/eugensystems/warno. The template has no shared game-data volume until that path is recorded.
- Two containers on one Unraid host showed online on 2026-10-09, on Game Ports `10400` and `10401`, with settings folders `/mnt/user/appdata/warno/10400/settings` and `/mnt/user/appdata/warno/10401/settings`. RAM per `warno-server` is not documented. See `docs/INSTALL-UNRAID.md`, section 8.
- `ghcr.io/suchamoneypit/warhost:latest` is published from `main`. `ghcr.io/suchamoneypit/warhost:dev` is published from `dev`. An anonymous read of `:latest` on 2026-10-09 is in `docs/ARCHITECTURE.md`. The 2026-10-10 rebuild for commit `eb4d65d` finished green; its manifest digest was not read. A failed rebuild leaves the previous image, so a new template can be installed against an old entrypoint until the run is green. The `main` template installs `:latest` and the `dev` template installs `:dev`. Both start with Map unset and serve the WebUI. The maintainer reported on 2026-10-13 that the published container serves the page.
- First-start duration and which sockets `warno-server` opens are still unrecorded. `ModList` for the Red Dragon pack is the mod's own `Version`: `3811913066/0` registered and did not log the rejected join; `3811913066/15` matched the pack on 2026-10-09; `3811913066/27` is the Red Dragon value read on 2026-10-10, and the template default is now empty. A bare id such as `3811913066` now reads that `Version` from Steam at each start; no running container has used it yet. See `docs/DECISIONS.md`.
- Eight slots on a 2v2 scenario (`NbMaxPlayer=8`, `MaxTeamSize=4`, Map `RDPort_JungleLaw_2v2_CONQ`) has not been tried. The WebUI can save those values, and a minimum of 2 with max 2 and team size 1. Eugen's page does not lock lobby size to the scenario ID. A Save and restart from the page has not been observed on a running Unraid container. See `docs/ARCHITECTURE.md`.

## Planned work

No planned work is recorded. Add a goal here in the same change as the work that starts it.
