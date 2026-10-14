---
name: map-previews
description: Extract Scenic view and Tactical zones map pictures from the local WARNO install into webui/previews/, which stays out of git.
disable-model-invocation: true
---

# /map-previews

Extract the Scenic view and Tactical zones pictures from the local WARNO install into `webui/previews/`. Do not commit that directory.

1. From the repository root, run `python3 scripts/extract_map_previews.py`.
2. Show the script summary: the base-map directory, how many workshop maps were read, how many pictures were written, and every scenario ID that still has no picture.
3. Stop. Do not copy `.dat` files into the repo, and do not add `webui/previews/` to a commit. The published image does not include those pictures.
