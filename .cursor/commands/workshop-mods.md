# /workshop-mods

Read the local WARNO Steam Workshop library and compare it with the README. Do not copy workshop files into the repo.

1. Launch `workshop-mod-reader`. Ask it to run `python3 scripts/list_workshop_mods.py --diff` and return the report shape in `.cursor/agents/workshop-mod-reader.md`.
2. Show that report. Version changes, mods on disk that the README does not list, scenario IDs the README does not list, and README pairs missing from the library all stay in the report.
3. Stop. Update `README.md`, `docs/INSTALL-UNRAID.md`, or `docs/ARCHITECTURE.md` only when this message also asks you to apply the report. When it does, add or replace the mod rows and scenario spoilers from the report, keep `Maps-Scenarios` when the report says `readme_tags: Maps-Scenarios`, then run `sh scripts/check_repo.sh`.
