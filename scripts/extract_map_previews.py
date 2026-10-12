#!/usr/bin/env python3
"""Copy Scenic view and Tactical zones pictures out of a local WARNO install.

Each battlefield's Maps/*_Details.dat archive stores Overview (the lobby
picture) and Preview (the top-down picture) as WebP or PNG. The .tgv files
in *_Assets.dat are left alone.

From the repository root:

  python3 scripts/extract_map_previews.py

Writes webui/previews/<map>/<overview|preview>.<webp|png> and index.json.
That directory is gitignored. Eugen's pictures are not committed.

--warno is the WARNO install. Without it, Steam libraryfolders.vdf is used.
--workshop is the workshop content directory for app 1611600. Without it,
subscribed mods are included. --no-workshop skips them.
--out replaces that directory. It must not be the repository root.
--self-test checks the archive reader and writes nothing under webui/.
"""

import argparse
import json
import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_OUT = ROOT / "webui" / "previews"
CATALOG = ROOT / "webui" / "scenarios.json"
PREVIEW_FILES = {
    "overview.webp",
    "overview.png",
    "preview.webp",
    "preview.png",
}


def archive_dict_size(data):
    if len(data) < 32 or data[:4] != b"edat":
        return None
    size = struct.unpack_from("<Q", data, 16)[0]
    if size < 64 or size >= len(data) or size > 2_000_000:
        return None
    return size


def entry_bytes(data, name_at, dict_size):
    end = data.find(b"\x00", name_at, dict_size)
    if end < 0 or end + 25 > dict_size:
        return None
    offset, size = struct.unpack_from("<QQ", data, end + 9)
    if size < 16 or size > 30_000_000:
        return None
    start = dict_size + offset
    if start < dict_size or start + size > len(data):
        return None
    blob = data[start:start + size]
    if blob.startswith(b"\x89PNG\r\n\x1a\n") and b"IEND" in blob:
        return blob, "png"
    if blob.startswith(b"RIFF") and blob[8:12] == b"WEBP" and len(blob) >= 12:
        declared = struct.unpack_from("<I", blob, 4)[0] + 8
        if 12 <= declared <= len(blob):
            return blob, "webp"
    return None


def picture(data, role):
    dict_size = archive_dict_size(data)
    if dict_size is None:
        return None
    window = data[:dict_size]
    for suffix in (b".webp", b".png", b"."):
        key = role.encode("ascii") + suffix
        start = 0
        while True:
            at = window.find(key, start)
            if at < 0:
                break
            start = at + 1
            if suffix == b".":
                rest = window[at + len(key):at + len(key) + 4]
                if rest.startswith((b"webp", b"png")):
                    continue
            found = entry_bytes(data, at, dict_size)
            if found:
                return found
    return None


def scenario_ids(catalog_path):
    data = json.loads(catalog_path.read_text())
    found = []
    for group in data.get("groups", []):
        for scenario in group.get("scenarios", []):
            scenario_id = scenario.get("id") or ""
            if scenario_id:
                found.append(scenario_id)
    return found


def covers(stem, scenario_id):
    return scenario_id == stem or scenario_id.startswith(stem + "_")


def wanted(stem, ids):
    if not ids:
        return True
    return any(covers(stem, scenario_id) for scenario_id in ids)


def build_number(path):
    nums = [int(part) for part in path.parts if part.isdigit()]
    return max(nums) if nums else -1


def map_directories(warno):
    pc = pathlib.Path(warno) / "Data" / "PC"
    if not pc.is_dir():
        return []
    found = []
    for child in pc.iterdir():
        if not child.is_dir() or child.is_symlink():
            continue
        direct = child / "Maps"
        if direct.is_dir() and not direct.is_symlink():
            found.append(direct)
        for nested in child.iterdir():
            if not nested.is_dir() or nested.is_symlink():
                continue
            maps = nested / "Maps"
            if maps.is_dir() and not maps.is_symlink():
                found.append(maps)
    return found


def detail_files(directory):
    files = []
    for path in directory.glob("*_Details.dat"):
        if path.is_symlink() or not path.is_file():
            continue
        if path.stat().st_size < 64:
            continue
        files.append(path)
    return files


def choose_base_maps(warno_roots):
    groups = {}
    for warno in warno_roots:
        for directory in map_directories(warno):
            files = detail_files(directory)
            if files:
                groups[directory] = files
    if not groups:
        return None, []

    def score(directory):
        total = sum(path.stat().st_size for path in groups[directory])
        return (build_number(directory), total)

    best = max(groups, key=score)
    return best, groups[best]


def workshop_maps(content_roots):
    files = []
    for root in content_roots:
        root = pathlib.Path(root)
        if not root.is_dir():
            continue
        for mod in root.iterdir():
            maps = mod / "Maps"
            if not maps.is_dir() or maps.is_symlink():
                continue
            files.extend(detail_files(maps))
    return files


def warno_roots(explicit):
    if explicit is not None:
        return [pathlib.Path(explicit)]
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    import list_workshop_mods

    found = []
    seen = set()
    for library in list_workshop_mods.library_paths():
        game = library / "steamapps" / "common" / "WARNO"
        if not game.is_dir():
            continue
        try:
            key = game.resolve()
        except OSError:
            key = game
        if key in seen:
            continue
        seen.add(key)
        found.append(game)
    return found


def read_pack(path):
    try:
        data = path.read_bytes()
    except OSError as exc:
        return None, str(exc)
    pictures = {}
    for role, slot in (("Overview", "overview"), ("Preview", "preview")):
        found = picture(data, role)
        if found:
            blob, ext = found
            pictures[slot] = (blob, ext)
    return pictures, None


def replace_output(out, written):
    out.mkdir(parents=True, exist_ok=True)
    keep = set(written) | {"index.json"}
    for child in out.iterdir():
        if child.name in keep:
            continue
        if child.is_symlink() or child.is_file():
            child.unlink()
            continue
        if child.is_dir():
            for item in child.iterdir():
                if item.is_symlink() or item.is_file():
                    item.unlink()
            child.rmdir()


def write_pack(out, stem, pictures):
    dest = out / stem
    dest.mkdir(parents=True, exist_ok=True)
    for item in dest.iterdir():
        if item.name not in PREVIEW_FILES and (item.is_file() or item.is_symlink()):
            item.unlink()
    record = {}
    for slot, (blob, ext) in pictures.items():
        name = "%s.%s" % (slot, ext)
        target = dest / name
        temporary = dest / (".%s.tmp" % name)
        temporary.write_bytes(blob)
        temporary.replace(target)
        record[slot] = name
        for other in ("webp", "png"):
            if other == ext:
                continue
            stale = dest / ("%s.%s" % (slot, other))
            if stale.is_file() or stale.is_symlink():
                stale.unlink()
    return record


def extract(warno, workshop, out, catalog_path, include_workshop):
    resolved = out.resolve()
    if resolved == pathlib.Path("/").resolve() or resolved == ROOT.resolve():
        raise SystemExit("refusing to replace this output directory")
    ids = scenario_ids(catalog_path) if catalog_path.is_file() else []
    base_dir, base_files = choose_base_maps(warno_roots(warno))
    mod_files = workshop_maps(workshop) if include_workshop else []
    if base_dir is None and not mod_files:
        raise SystemExit("WARNO map packs were not found. Pass --warno or install the game in Steam.")

    packs = []
    for path in base_files:
        packs.append(("base", path))
    for path in mod_files:
        packs.append(("workshop", path))

    written = {}
    skipped = []
    for kind, path in packs:
        stem = path.name[: -len("_Details.dat")]
        if not wanted(stem, ids):
            continue
        if stem in written and kind == "workshop":
            continue
        pictures, error = read_pack(path)
        if error or ("overview" not in pictures and "preview" not in pictures):
            skipped.append(stem)
            continue
        written[stem] = write_pack(out, stem, pictures)

    replace_output(out, written)
    # write_pack already created files; replace_output removes stale stems.
    # Recreate index after cleanup so a stale index cannot survive.
    index_path = out / "index.json"
    index_path.write_text(json.dumps(written, indent=2, sort_keys=True) + "\n")
    return base_dir, base_files, mod_files, written, skipped, ids


def report(base_dir, base_files, mod_files, written, skipped, ids):
    print("base maps: %d%s" % (len(base_files), "" if base_dir is None else " from %s" % base_dir))
    print("workshop maps: %d" % len(mod_files))
    print("wrote: %d" % len(written))
    if skipped:
        print("skipped: %d" % len(skipped))
        for stem in skipped:
            print("skipped %s" % stem)
    missing = [scenario_id for scenario_id in ids if not any(covers(stem, scenario_id) for stem in written)]
    print("scenario ids without a picture: %d" % len(missing))
    for scenario_id in missing:
        print(scenario_id)


def tiny_png():
    def chunk(tag, payload):
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)
    raw = zlib.compress(b"\x00\xff\x00\x00")
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", raw) + chunk(b"IEND", b"")


def tiny_webp():
    body = b"WEBPVP8 " + b"\x00" * 8
    return b"RIFF" + struct.pack("<I", len(body)) + body


def sample_archive(overview, preview):
    dict_size = 512
    directory = bytearray(dict_size)
    payload = overview + preview
    struct.pack_into("<4sIIIQQ", directory, 0, b"edat", 3, 256, 64, dict_size, len(payload))

    def entry(name, offset, size):
        return name + b"\x00\x00\x00\x00\x00" + struct.pack("<IQQ", 0x35, offset, size)

    first = entry(b"Overview.webp", 0, len(overview))
    second = entry(b"Preview.webp", len(overview), len(preview))
    blob = bytes(directory[:64]) + first + second
    if len(blob) > dict_size:
        raise SystemExit("self-test dictionary is too small")
    return blob + bytes(dict_size - len(blob)) + payload


def self_test():
    overview = tiny_png()
    preview = tiny_webp()
    data = sample_archive(overview, preview)
    found_overview = picture(data, "Overview")
    found_preview = picture(data, "Preview")
    if found_overview != (overview, "png") or found_preview != (preview, "webp"):
        raise SystemExit("self-test did not read Overview and Preview")
    dict_size = 512
    directory = bytearray(dict_size)
    struct.pack_into("<4sIIIQQ", directory, 0, b"edat", 3, 256, 64, dict_size, len(overview))
    entry = b"Overview.\x00\x00\x00\x00\x00" + struct.pack("<IQQ", 0x35, 0, len(overview))
    dotted = bytes(directory[:64]) + entry + bytes(dict_size - 64 - len(entry)) + overview
    if picture(dotted, "Overview") != (overview, "png"):
        raise SystemExit("self-test did not read a dotted Overview name")
    if picture(data, "Minimap") is not None:
        raise SystemExit("self-test invented a Minimap picture")
    ids = ["_2x2_Hesse_2vs2_CONQ", "RDPort_JungleLaw_2v2_CONQ"]
    if not wanted("_2x2_Hesse", ids) or wanted("SM_U_2x2_Hesse_01", ids):
        raise SystemExit("self-test kept a map the catalog does not list")
    if not covers("_2x2_Hesse", "_2x2_Hesse_1vs1_CONQ_DUEL"):
        raise SystemExit("self-test missed a scenario on the same battlefield")
    print("self-test ok")


def main():
    parser = argparse.ArgumentParser(description="Extract WARNO map preview pictures.")
    parser.add_argument("--warno", type=pathlib.Path, help="WARNO install directory")
    parser.add_argument("--workshop", type=pathlib.Path, help="workshop content directory for app 1611600")
    parser.add_argument("--no-workshop", action="store_true")
    parser.add_argument("--out", type=pathlib.Path, default=DEFAULT_OUT)
    parser.add_argument("--catalog", type=pathlib.Path, default=CATALOG)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    out = args.out
    resolved = out.resolve()
    if resolved == pathlib.Path("/").resolve() or resolved == ROOT.resolve():
        raise SystemExit("refusing to replace this output directory")
    if args.no_workshop:
        workshop = []
    elif args.workshop is not None:
        workshop = [args.workshop]
    else:
        sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
        import list_workshop_mods
        workshop = list_workshop_mods.workshop_dirs(None)
    result = extract(args.warno, workshop, out, args.catalog, not args.no_workshop)
    report(*result)


if __name__ == "__main__":
    main()
