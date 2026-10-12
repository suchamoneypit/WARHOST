#!/usr/bin/env python3
"""Build webui/scenarios.json from the scenario tables in README.md."""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
README = ROOT / "README.md"
OUT = pathlib.Path(__file__).resolve().parent / "scenarios.json"

GROUPS = (
    ("Red Dragon", "Red Dragon map pack", "3811913066/27", "Maps-Scenarios"),
    ("WEST FULDA", "WEST FULDA 1.0", "3363584349/1023", "Maps-Scenarios"),
    ("Highway to Oslo", "Highway to Oslo", "3474588989/14", "Maps-Scenarios"),
    ("Ramstein", "Ramstein Air Base", "3705706772/9", "Maps-Scenarios"),
    ("Arsenal", "Arsenal", "3415339374/20", "Maps-Scenarios"),
    ("Helbe", "Helbe", "3762638679/36", "Maps-Scenarios"),
    ("Base game", "Base game", "", ""),
)


def slots(size, scenario_id):
    text = f"{size} {scenario_id}"
    for token, players, team in (
        ("10v10", 20, 10),
        ("10vs10", 20, 10),
        ("4v4", 8, 4),
        ("4vs4", 8, 4),
        ("3v3", 6, 3),
        ("3vs3", 6, 3),
        ("2v2", 4, 2),
        ("2vs2", 4, 2),
        ("1v1", 2, 1),
        ("1vs1", 2, 1),
    ):
        if token in text:
            return players, team
    if "_6P" in scenario_id:
        return 6, 3
    if "TwoHills" in scenario_id:
        return 4, 2
    if "Oslo" in scenario_id:
        return 2, 1
    if "Ramstein" in scenario_id:
        return 6, 3
    raise SystemExit(f"no player count for {scenario_id} ({size})")


def combat_rule(size, scenario_id):
    blob = f"{size} {scenario_id}"
    if "DEST" in scenario_id or "Destruction" in blob:
        return 1
    if "CONQ" in scenario_id or "Conquest" in blob:
        return 2
    raise SystemExit(f"no combat rule for {scenario_id} ({size})")


def gameplay_mods(readme):
    start = readme.index("| Mod | Workshop Mod List |")
    group_ids = set()
    for _needle, _name, mod_list, _tags in GROUPS:
        if mod_list:
            group_ids.add(mod_list.split("/", 1)[0])
    mods = []
    for line in readme[start:].splitlines():
        if line.startswith("####") or line.startswith("The pin column"):
            break
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 4 or "Workshop Mod List" in cells[1] or set(cells[1]) <= {"-"}:
            continue
        name = re.search(r"\[([^\]]+)\]", cells[0])
        ids = re.findall(r"`([^`]+)`", cells[1])
        pins = re.findall(r"`([^`]+)`", cells[2])
        tags = re.findall(r"`([^`]+)`", cells[3])
        if name is None or not ids:
            raise SystemExit(f"workshop row has no mod: {line}")
        mod_id = ids[0]
        if mod_id in group_ids:
            continue
        mods.append(
            {
                "name": name.group(1),
                "id": mod_id,
                "modList": pins[0] if pins else mod_id,
                "modTags": tags[0] if tags else "",
                "tagsWithMapPack": tags[1] if len(tags) > 1 else "",
            }
        )
    if [mod["id"] for mod in mods] != ["3595948209", "3388575848"]:
        raise SystemExit(f"gameplay mods {[mod['id'] for mod in mods]}")
    return mods


def catalog(readme):
    groups = []
    for part in readme.split("<details>")[1:]:
        summary = re.sub(r"<[^>]+>", "", part.split("</summary>", 1)[0]).strip()
        matched = None
        for needle, name, mod_list, mod_tags in GROUPS:
            if needle in summary:
                matched = (name, mod_list, mod_tags)
                break
        if matched is None:
            continue
        body = part.split("</details>", 1)[0]
        scenarios = []
        for line in body.splitlines():
            if not line.startswith("|"):
                continue
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            if len(cells) < 3 or "Scenario ID" in cells[1] or set(cells[1]) <= {"-"}:
                continue
            found = re.search(r"`([^`]+)`", cells[1])
            if not found:
                continue
            scenario_id = found.group(1)
            if scenario_id.startswith("SM_"):
                continue
            players, team = slots(cells[2], scenario_id)
            scenarios.append(
                {
                    "name": cells[0],
                    "id": scenario_id,
                    "size": cells[2],
                    "players": players,
                    "team": team,
                    "rule": combat_rule(cells[2], scenario_id),
                }
            )
        if not scenarios:
            raise SystemExit(f"no scenarios in {summary}")
        groups.append(
            {
                "name": matched[0],
                "modList": matched[1],
                "modTags": matched[2],
                "scenarios": scenarios,
            }
        )
    expected = [item[1] for item in GROUPS]
    if [group["name"] for group in groups] != expected:
        raise SystemExit(f"group order {[group['name'] for group in groups]}")
    return {"groups": groups, "mods": gameplay_mods(readme)}


def main():
    data = catalog(README.read_text())
    text = json.dumps(data, indent=2) + "\n"
    if "--check" in sys.argv:
        if OUT.read_text() != text:
            raise SystemExit("webui/scenarios.json does not match README.md")
        counts = [len(group["scenarios"]) for group in data["groups"]]
        if counts != [28, 16, 4, 2, 4, 12, 102]:
            raise SystemExit(f"scenario counts {counts}")
        return
    OUT.write_text(text)


if __name__ == "__main__":
    main()
