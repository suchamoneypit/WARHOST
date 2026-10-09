# Roadmap

Confirmed from `README.md` and the repository state on 2026-10-09. No other goals are recorded here.

## Current goals

1. Install the template on an Unraid server and confirm the container stays up, the dedicated key exists only in that server's settings files, and the running scenario is Jungle Law.
2. After that test, submit the repository at https://ca.unraid.net/submit.

## Known issues

- The repository has no record of a completed Unraid install test. The README defers the Community Apps listing until that test exists. `docs/INSTALL-UNRAID.md` is the walkthrough for that test.
- Whether the dedicated server downloads workshop item `3811913066` by itself has not been observed. Eugen's docs only describe the client download prompt: https://hub.docker.com/r/eugensystems/warno
- `ghcr.io/suchamoneypit/warhost:latest` is the only tag the rebuild workflow publishes. An anonymous pull of that tag has not been recorded in this repository. The 2026-10-09 public-pull check was of the former package `warno-unraid` (see `docs/ARCHITECTURE.md`).
- First-start duration and which sockets `warno-server` opens are still unrecorded. `ModList` for the Red Dragon pack is the mod's own `Version`: `3811913066/0` registered and did not log the rejected join; `3811913066/15` is the preset. See `docs/DECISIONS.md`.
- Eight slots on a 2v2 scenario (`NbMaxPlayer=8`, `MaxTeamSize=4`, Map `RDPort_JungleLaw_2v2_CONQ`) has not been tried. Eugen's page does not lock lobby size to the scenario ID. See `docs/ARCHITECTURE.md`.

## Planned work

The two current goals above are the only planned work stated by the project.
