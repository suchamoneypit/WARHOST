# Roadmap

Goals and known issues, last updated 2026-10-13.

## Current goals

None recorded. Both earlier goals are done, as the maintainer reported on 2026-10-13:

- The Unraid install test: the container stays up, the dedicated key exists only in that server's settings files, and the running scenario is the preset Hesse map.
- The Community Applications submission: the listing is published.

## Known issues

- Whether the dedicated server downloads workshop item `3811913066` by itself has not been observed. Eugen's docs only describe the client download prompt: https://hub.docker.com/r/eugensystems/warno. The template has no shared game-data volume until that path is recorded.
- First-start duration and which sockets `warno-server` opens are still unrecorded.
- A bare Workshop id has not been resolved on a running WARHOST container.
- Eight slots on a 2v2 scenario (`NbMaxPlayer=8`, `MaxTeamSize=4`, Map `RDPort_JungleLaw_2v2_CONQ`) has not been tried. The WebUI can save those values. A Save and restart from the page has not been observed on a running Unraid container. See `docs/ARCHITECTURE.md`.

## Planned work

No planned work is recorded. Add a goal here in the same change as the work that starts it.
