#!/usr/bin/env python3
"""List subscribed WARNO workshop mods and compare them with README.md.

Reads Name, ID, Version, and TagList from each mod's Config.ini, and the
scenario file names in Scenarios/. PreviewImagePath is never printed.

From the repository root:

  python3 scripts/list_workshop_mods.py --diff

--root is the workshop content directory (Steam app 1611600). Without it,
the script uses libraryfolders.vdf under the local Steam install.
--diff prints mods whose version or scenario IDs differ from --readme
(default: this repo's README.md). A difference is not an error.
"""

import argparse
import pathlib
import re
import sys
import tempfile

APP_ID = "1611600"
PROP_KEYS = ("Name", "ID", "Version", "TagList")
SCENARIO_SUFFIXES = (
    "_Assets.dat",
    "_Definition.dat",
    "_Details.dat",
    "_GameData.dat",
)
ROOT = pathlib.Path(__file__).resolve().parent.parent
README_PAIR = re.compile(r"(?<![A-Za-z0-9_])(\d{6,})/(\d+)(?![A-Za-z0-9_])")


def unescape_vdf(value):
    return value.replace("\\\\", "\\")


def library_paths():
    home = pathlib.Path.home()
    configs = (
        home / ".local/share/Steam/config/libraryfolders.vdf",
        home / ".steam/steam/config/libraryfolders.vdf",
        home / ".steam/root/config/libraryfolders.vdf",
    )
    found = []
    seen = set()
    for config in configs:
        if not config.is_file():
            continue
        text = config.read_text(errors="replace")
        for raw in re.findall(r'"path"\s+"([^"]+)"', text):
            path = pathlib.Path(unescape_vdf(raw))
            key = str(path)
            if key not in seen:
                seen.add(key)
                found.append(path)
        steam_root = config.parent.parent
        key = str(steam_root)
        if key not in seen:
            seen.add(key)
            found.append(steam_root)
    return found


def workshop_dirs(explicit_root):
    if explicit_root is not None:
        return [pathlib.Path(explicit_root)]
    found = []
    seen = set()
    for library in library_paths():
        content = library / "steamapps" / "workshop" / "content" / APP_ID
        if not content.is_dir():
            continue
        try:
            key = content.resolve()
        except OSError:
            key = content
        if key in seen:
            continue
        seen.add(key)
        found.append(content)
    return found


def parse_config(path):
    props = {}
    in_properties = True
    for line in path.read_text(errors="replace").splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            in_properties = stripped.lower() == "[properties]"
            continue
        if not in_properties or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        key = key.strip()
        if key not in PROP_KEYS:
            continue
        props[key] = value.split(";", 1)[0].strip()
    return props


def scenario_ids(scenarios_dir):
    if not scenarios_dir.is_dir():
        return None
    found = set()
    for entry in scenarios_dir.iterdir():
        if not entry.is_file():
            continue
        name = entry.name
        for suffix in SCENARIO_SUFFIXES:
            if name.endswith(suffix):
                found.add(name[: -len(suffix)])
                break
    return sorted(found)


def load_mods(content_dir):
    mods = []
    if not content_dir.is_dir():
        return mods
    for entry in content_dir.iterdir():
        if not entry.is_dir() or not entry.name.isdigit():
            continue
        config_path = entry / "Config.ini"
        props = parse_config(config_path) if config_path.is_file() else {}
        ids = scenario_ids(entry / "Scenarios")
        skirmish = []
        army = []
        if ids is not None:
            for scenario_id in ids:
                if scenario_id.startswith("SM_"):
                    army.append(scenario_id)
                else:
                    skirmish.append(scenario_id)
        mods.append(
            {
                "folder": entry.name,
                "path": entry,
                "name": props.get("Name", ""),
                "id": props.get("ID", ""),
                "version": props.get("Version", ""),
                "tags": props.get("TagList", ""),
                "scenarios": None if ids is None else skirmish,
                "army_general": None if ids is None else army,
            }
        )
    mods.sort(key=lambda mod: int(mod["folder"]))
    return mods


def mentioned(text, token):
    pattern = r"(?<![A-Za-z0-9_])" + re.escape(token) + r"(?![A-Za-z0-9_])"
    return re.search(pattern, text) is not None


def readme_versions(text, workshop_id):
    pattern = re.compile(
        r"(?<![A-Za-z0-9_])" + re.escape(workshop_id) + r"/(\d+)(?![A-Za-z0-9_])"
    )
    return sorted(set(pattern.findall(text)), key=int)


def classify(mod, readme):
    workshop_id = mod["id"] or mod["folder"]
    versions = readme_versions(readme, workshop_id) if readme is not None else []
    pair = "{0}/{1}".format(workshop_id, mod["version"]) if mod["version"] else ""
    if readme is None:
        state = "uncompared"
    elif mod["version"] and mod["version"] in versions:
        state = "version_match"
    elif versions:
        state = "version_diff"
    else:
        state = "not_in_readme"

    missing_scenarios = []
    missing_army = []
    if readme is not None and mod["scenarios"] is not None:
        missing_scenarios = [item for item in mod["scenarios"] if not mentioned(readme, item)]
        missing_army = [item for item in mod["army_general"] if not mentioned(readme, item)]
    return {
        "id": workshop_id,
        "pair": pair,
        "readme_versions": versions,
        "state": state,
        "missing_scenarios": missing_scenarios,
        "missing_army": missing_army,
    }


def tag_lines(tags):
    words = [word.strip() for word in tags.split(",") if word.strip()]
    lines = ["tags: {0}".format(tags if tags else "(none)")]
    if words:
        lines.append("tag_string: {0}".format("-".join(words)))
    if set(words) == {"Scenarios", "Maps"}:
        lines.append("readme_tags: Maps-Scenarios")
    return lines


def format_id_list(label, items):
    if items is None:
        return ["{0}: (no Scenarios directory)".format(label)]
    if not items:
        return ["{0}: (none)".format(label)]
    return ["{0}:".format(label)] + ["  - {0}".format(item) for item in items]


def format_mod(mod, info, full):
    title = mod["name"] or "(no Name)"
    lines = ["{0} {1} {2}".format(info["state"], info["id"], title)]
    lines.append("  path: {0}".format(mod["path"]))
    if mod["id"] and mod["id"] != mod["folder"]:
        lines.append("  folder: {0}".format(mod["folder"]))
    lines.append("  mod_list: {0}".format(info["pair"] or "(no Version)"))
    if info["readme_versions"]:
        lines.append(
            "  readme: {0}".format(
                ", ".join("{0}/{1}".format(info["id"], version) for version in info["readme_versions"])
            )
        )
    for tag_line in tag_lines(mod["tags"]):
        lines.append("  {0}".format(tag_line))
    if full or info["state"] == "not_in_readme":
        lines.extend("  {0}".format(line) for line in format_id_list("scenarios", mod["scenarios"]))
        lines.extend("  {0}".format(line) for line in format_id_list("army_general", mod["army_general"]))
    else:
        lines.extend("  {0}".format(line) for line in format_id_list("scenarios_missing", info["missing_scenarios"] if mod["scenarios"] is not None else None))
        lines.extend("  {0}".format(line) for line in format_id_list("army_general_missing", info["missing_army"] if mod["army_general"] is not None else None))
    return "\n".join(lines)


def readme_only(readme, mods):
    on_disk = set()
    for mod in mods:
        on_disk.add(mod["folder"])
        if mod["id"]:
            on_disk.add(mod["id"])
    missing = []
    seen = set()
    for workshop_id, version in README_PAIR.findall(readme):
        if workshop_id in on_disk or workshop_id in seen or workshop_id == APP_ID:
            continue
        seen.add(workshop_id)
        missing.append("{0}/{1}".format(workshop_id, version))
    return missing


def render(content_dirs, mods, readme, diff_only):
    lines = ["libraries:"]
    if content_dirs:
        lines.extend("  - {0}".format(path) for path in content_dirs)
    else:
        lines.append("  - (none)")
    lines.append("on_disk: {0}".format(len(mods)))
    infos = [(mod, classify(mod, readme)) for mod in mods]
    interesting = []
    unchanged = 0
    for mod, info in infos:
        if diff_only and info["state"] == "version_match" and not info["missing_scenarios"] and not info["missing_army"]:
            unchanged += 1
            continue
        interesting.append((mod, info))
    if diff_only and readme is not None:
        lines.append("unchanged: {0}".format(unchanged))
    only = readme_only(readme, mods) if readme is not None else []
    if readme is not None:
        lines.append("readme_only: {0}".format(len(only)))
        for pair in only:
            lines.append("  - {0}".format(pair))
    if not interesting and diff_only:
        lines.append("diff: none")
        return "\n".join(lines)
    lines.append("mods:")
    for mod, info in interesting:
        lines.append(format_mod(mod, info, full=not diff_only))
    return "\n".join(lines)


def build_parser():
    parser = argparse.ArgumentParser(description="List local WARNO workshop mods.")
    parser.add_argument("--root", type=pathlib.Path, help="workshop content directory for app 1611600")
    parser.add_argument("--readme", type=pathlib.Path, help="README to compare; default is this repo's README.md with --diff")
    parser.add_argument("--diff", action="store_true", help="print only mods that differ from the README")
    parser.add_argument("--self-test", action="store_true", help="run the fixture check and print nothing else")
    return parser


def main(argv):
    args = build_parser().parse_args(argv)
    if args.self_test:
        return self_test()
    content_dirs = workshop_dirs(args.root)
    if not content_dirs:
        print("no WARNO workshop folder found (steamapps/workshop/content/{0})".format(APP_ID), file=sys.stderr)
        return 1
    mods = []
    for content_dir in content_dirs:
        mods.extend(load_mods(content_dir))
    readme_path = args.readme
    if args.diff and readme_path is None:
        readme_path = ROOT / "README.md"
    readme = None
    if readme_path is not None:
        if not readme_path.is_file():
            print("readme not found: {0}".format(readme_path), file=sys.stderr)
            return 1
        readme = readme_path.read_text(errors="replace")
    print(render(content_dirs, mods, readme, args.diff))
    return 0


def write_scenario(directory, scenario_id):
    for suffix in SCENARIO_SUFFIXES:
        (directory / "{0}{1}".format(scenario_id, suffix)).write_text("x")


def self_test():
    with tempfile.TemporaryDirectory() as temp_name:
        root = pathlib.Path(temp_name)
        content = root / "1611600"
        mod_dir = content / "3474588989"
        scenarios = mod_dir / "Scenarios"
        scenarios.mkdir(parents=True)
        secret = r"C:\Users\secretname\SteamPre.png"
        (mod_dir / "Config.ini").write_text(
            "\n".join(
                (
                    "[Properties]",
                    "Name = Oslo",
                    "TagList = Scenarios,Maps ; do not modify",
                    "PreviewImagePath = {0}".format(secret),
                    "ID = 3474588989 ; do not modify",
                    "Version = 14 ; increment when incompatible",
                    "",
                    "[Config]",
                    "GFX/Unit=abc",
                    "Name = hidden",
                )
            )
        )
        write_scenario(scenarios, "_2x2_Oslo_Conquest")
        write_scenario(scenarios, "_2x2_Oslo_ConquestNS")
        write_scenario(scenarios, "SM_FO_2x2_Oslo_01")
        readme = root / "README.md"
        readme.write_text(
            "Path steamapps/workshop/content/1611600/3474588989.\n"
            "Workshop Mod List `3474588989/9` and `_2x2_Oslo_ConquestNS` only.\n"
        )
        mods = load_mods(content)
        if len(mods) != 1:
            print("self-test expected 1 mod, got {0}".format(len(mods)), file=sys.stderr)
            return 1
        rendered = render([content], mods, readme.read_text(), diff_only=True)
        if "secretname" in rendered or "PreviewImagePath" in rendered or "GFX/Unit" in rendered:
            print("self-test leaked a config path or hash", file=sys.stderr)
            return 1
        for required in (
            "version_diff 3474588989 Oslo",
            "mod_list: 3474588989/14",
            "readme: 3474588989/9",
            "tag_string: Scenarios-Maps",
            "readme_tags: Maps-Scenarios",
            "_2x2_Oslo_Conquest",
            "SM_FO_2x2_Oslo_01",
        ):
            if required not in rendered:
                print("self-test missing {0!r}".format(required), file=sys.stderr)
                print(rendered, file=sys.stderr)
                return 1
        if "  - _2x2_Oslo_Conquest\n" not in rendered:
            print("self-test scenario boundary failed", file=sys.stderr)
            print(rendered, file=sys.stderr)
            return 1
        if "readme_only: 0" not in rendered:
            print("self-test treated the app id path as a mod", file=sys.stderr)
            print(rendered, file=sys.stderr)
            return 1
        if "  - _2x2_Oslo_ConquestNS" in rendered:
            print("self-test treated a present NS id as missing", file=sys.stderr)
            print(rendered, file=sys.stderr)
            return 1
        matched = readme.read_text().replace("3474588989/9", "3474588989/14")
        matched = matched.replace(
            "`_2x2_Oslo_ConquestNS`",
            "`_2x2_Oslo_Conquest` `_2x2_Oslo_ConquestNS` `SM_FO_2x2_Oslo_01`",
        )
        quiet = render([content], mods, matched, diff_only=True)
        if "diff: none" not in quiet or "version_diff" in quiet:
            print("self-test expected no diff", file=sys.stderr)
            print(quiet, file=sys.stderr)
            return 1
    print("workshop mod listing ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
