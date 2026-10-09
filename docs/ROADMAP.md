# Roadmap

Confirmed from `README.md` and the repository state on 2026-10-09. No other goals are recorded here.

## Current goals

1. Install the template on an Unraid server and confirm the container stays up, the dedicated key exists only in that server's settings files, and the running scenario is Jungle Law.
2. After that test, submit the repository at https://ca.unraid.net/submit.

## Known issues

- The repository has no record of a completed Unraid install test. The README defers the Community Apps listing until that test exists. `docs/INSTALL-UNRAID.md` is the walkthrough for that test.
- Whether the dedicated server downloads workshop item `3811913066` by itself has not been observed. Eugen's docs only describe the client download prompt: https://hub.docker.com/r/eugensystems/warno
- The GHCR image was confirmed publicly pullable on 2026-10-09 (see `docs/ARCHITECTURE.md`). The earlier README statement that it did not exist yet was removed in the documentation pass of that date.
- First-start duration and which sockets `warno-server` opens are still unrecorded. `ModList` for the Red Dragon pack is the mod's own `Version`: `3811913066/0` registered and did not log the rejected join; `3811913066/15` is the preset. See `docs/DECISIONS.md`.

## Planned work

The two current goals above are the only planned work stated by the project.
