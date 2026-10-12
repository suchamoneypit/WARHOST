"""Validate a WebUI save and replace variables.ini. Never reads login.ini."""

import json
import os
import re
import shutil
import tempfile
from pathlib import Path

MENU_UPKEEP = (0, 5, 7)
MENU_MONEY = (500, 750, 1000, 1500, 2000, 2500, 3000)
MENU_TIME = (1200, 1800, 2400, 3600, 0)
MENU_SCORE = (1000, 2000, 4000)
MENU_INCOME = (0, 1, 2, 3, 4, 5)
MENU_GAME_TYPE = (0, 1, 2)

UNCHANGED_RESTART = "No settings have changed, are you sure you want to restart the container?"
CHANGED_RESTART = "Save these settings and restart the container? The current match will stop."

SEEDED = {
    "MapRotationType": "0",
    "WarmupCountdown": "60",
    "LoadingTimeMax": "120",
    "DeploiementTimeMax": "120",
    "DebriefingTimeMax": "60",
    "DeltaMaxTeamSize": "0",
    "AllowObservers": "1",
    "ObserverDelay": "120",
}

MANAGED = {
    "ServerName",
    "NbMaxPlayer",
    "NbMinPlayer",
    "MaxTeamSize",
    "GameType",
    "CoopVsAI",
    "CombatRule",
    "Map",
    "ModList",
    "ModTagList",
    "InitMoney",
    "TimeLimit",
    "ScoreLimit",
    "IncomeRate",
    "Upkeep",
    *SEEDED,
}

LINE = re.compile(r"^([A-Za-z][A-Za-z0-9]*) = ([^\r\n]*)$")
MOD_LIST = re.compile(r"^[0-9]+(/[0-9]+)?(-[0-9]+(/[0-9]+)?)*$")
MOD_TAGS = re.compile(r"^[A-Za-z]+(-[A-Za-z]+)*$")


class LobbyError(Exception):
    pass


def _canonical_number(value, low, high):
    text = str(value).strip()
    if not text.isdigit():
        raise LobbyError("A lobby value must be a whole number.")
    number = int(text)
    if str(number) != text or number < low or number > high:
        raise LobbyError("A lobby value is outside the menu.")
    return number


def _keep_current(posted, current, allowed):
    number = _canonical_number(posted, 0, 100000000)
    if number in allowed or (current is not None and number == current):
        return number
    raise LobbyError("A lobby value is outside the menu.")


def read_ini(path):
    path = Path(path)
    if path.is_symlink():
        raise LobbyError("variables.ini is a symlink, so it was not read.")
    if not path.is_file():
        return {}
    values = {}
    extras = []
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        match = LINE.match(line)
        if not match:
            raise LobbyError("variables.ini has a line this page cannot keep.")
        key, value = match.group(1), match.group(2)
        if key in ("login", "dedicated_key"):
            raise LobbyError("variables.ini has a line this page cannot keep.")
        if key in values:
            raise LobbyError("variables.ini repeats a setting.")
        values[key] = value
        if key not in MANAGED:
            extras.append((key, value))
    return {"values": values, "extras": extras}


def _require_text(value, label, limit):
    text = "" if value is None else str(value)
    if not text or len(text) > limit or "\n" in text or "\r" in text or "=" in text:
        raise LobbyError(f"{label} is empty or contains = or a line break.")
    return text


def _scenario_index(catalog):
    index = {}
    for group in catalog["groups"]:
        for scenario in group["scenarios"]:
            index[scenario["id"]] = (group, scenario)
    return index


def _pack_id(group):
    mod_list = group.get("modList") or ""
    if not mod_list:
        return ""
    return mod_list.split("/", 1)[0]


def _current_int(values, key):
    text = values.get(key)
    if text is None or not str(text).isdigit():
        return None
    number = int(text)
    if str(number) != str(text):
        return None
    return number


TAG_WORDS = ("Gameplay", "Interface", "Maps", "Scenarios", "Music", "Sound")


def catalog_mods(catalog):
    mods = []
    for group in catalog["groups"]:
        mod_list = group.get("modList") or ""
        if not mod_list:
            continue
        mods.append(
            {
                "id": mod_list.split("/", 1)[0],
                "tags": group.get("modTags") or "",
                "tagsWithMapPack": "",
                "mapPack": bool(group.get("scenarios")),
            }
        )
    for mod in catalog.get("mods") or []:
        mods.append(
            {
                "id": str(mod.get("id") or ""),
                "tags": mod.get("modTags") or "",
                "tagsWithMapPack": mod.get("tagsWithMapPack") or "",
                "mapPack": False,
            }
        )
    return mods


def _merge_mods(posted, existing_list, known_ids):
    if not isinstance(posted, list):
        raise LobbyError("The WebUI sent an unreadable save.")
    existing_entries = [part for part in existing_list.split("-") if part] if existing_list else []
    existing_ids = [part.split("/", 1)[0] for part in existing_entries]
    if len(posted) != len(set(posted)):
        raise LobbyError("Workshop mod list repeats an id.")
    for item in posted:
        if not isinstance(item, str) or not item.isdigit():
            raise LobbyError("Workshop mod list is not an id/version list.")
        if item not in known_ids and item not in existing_ids:
            raise LobbyError("That workshop mod is not in the list.")
    result = []
    seen = set()
    for entry in existing_entries:
        bare = entry.split("/", 1)[0]
        if bare not in posted or bare in seen:
            continue
        seen.add(bare)
        result.append(bare if bare in known_ids else entry)
    for bare in posted:
        if bare in seen:
            continue
        result.append(bare)
        seen.add(bare)
    return "-".join(result)


def _derive_tags(selected_ids, catalog, previous_tags):
    known = {mod["id"]: mod for mod in catalog_mods(catalog)}
    chosen = [known[item] for item in selected_ids if item in known]
    if not chosen:
        if any(item not in known for item in selected_ids):
            return previous_tags
        return ""
    map_pack = any(mod["mapPack"] for mod in chosen)
    strings = []
    for mod in chosen:
        if map_pack and mod["tagsWithMapPack"]:
            strings.append(mod["tagsWithMapPack"])
        elif mod["tags"]:
            strings.append(mod["tags"])
    if len(strings) == 1:
        return strings[0]
    seen = []
    for text in strings:
        for word in text.split("-"):
            if word and word not in seen:
                seen.append(word)
    ranked = [word for word in TAG_WORDS if word in seen]
    ranked.extend(word for word in seen if word not in ranked)
    return "-".join(ranked)


def _player_count(value, low, high, whole, bounds):
    text = str(value).strip()
    if not text.isdigit():
        raise LobbyError(whole)
    number = int(text)
    if str(number) != text or number < low or number > high:
        raise LobbyError(bounds)
    return number


def _posted(payload, key):
    if not isinstance(payload, dict) or key not in payload:
        return False
    value = payload.get(key)
    if value is None or str(value).strip() == "":
        return False
    return True


def _choose_count(payload, key, values, ini_key, use_file, base, low, high, whole, bounds):
    if _posted(payload, key):
        return _player_count(payload.get(key), low, high, whole, bounds)
    if use_file and ini_key in values:
        return _player_count(values.get(ini_key), low, high, whole, bounds)
    return _player_count(base, low, high, whole, bounds)


def _setup(payload):
    if not isinstance(payload, dict):
        raise LobbyError("The WebUI sent an unreadable save.")
    setup = payload.get("setup", "pvp")
    if setup in (None, ""):
        setup = "pvp"
    if setup not in ("pvp", "pve"):
        raise LobbyError("Setup must be PvP or PvE setup.")
    return setup


def _ai_side(human_side):
    return "1" if human_side == 1 else "0"


def _deck_name(value):
    text = "" if value is None else str(value).strip()
    if not text or len(text) > 64 or any(char in text for char in "\r\n"):
        raise LobbyError("A deck name is empty or too long.")
    return text


def _deck_code(value):
    text = "" if value is None else str(value).strip()
    if not text or len(text) > 2000 or any(char.isspace() for char in text):
        raise LobbyError("A deck code must be one token.")
    return text


def _validate_decks(posted, human_side):
    if not isinstance(posted, dict):
        raise LobbyError("PvE setup needs an AI deck.")
    result = {}
    for side in ("0", "1"):
        rows = posted.get(side, [])
        if not isinstance(rows, list):
            raise LobbyError("PvE setup needs an AI deck.")
        if len(rows) > 8:
            raise LobbyError("Each side can have at most 8 decks.")
        cleaned = []
        for row in rows:
            if not isinstance(row, dict):
                raise LobbyError("PvE setup needs an AI deck.")
            cleaned.append(
                {
                    "name": _deck_name(row.get("name")),
                    "deckContent": _deck_code(row.get("deckContent")),
                    "iaLevel": _canonical_number(row.get("iaLevel"), 1, 6),
                }
            )
        result[side] = cleaned
    if not result[_ai_side(human_side)]:
        raise LobbyError("PvE setup needs an AI deck.")
    return result


def counts_from_values(values):
    def num(key, default):
        text = values.get(key, default)
        if str(text).isdigit():
            return int(text)
        return int(default)

    players = num("NbMaxPlayer", "4")
    minimum = num("NbMinPlayer", "2")
    team = num("MaxTeamSize", "2")
    delta = num("DeltaMaxTeamSize", "0")
    humans = minimum
    ai = players - humans
    if (
        humans < 1
        or ai < 1
        or humans + ai != players
        or max(humans, ai) != team
        or abs(humans - ai) != delta
    ):
        humans = team if team >= 1 else 2
        ai = humans
    return humans, ai


def read_decks(path):
    empty = {"0": [], "1": []}
    path = Path(path)
    if path.is_symlink() or not path.is_file():
        return {"0": [], "1": []}
    try:
        data = json.loads(path.read_text())
    except (OSError, UnicodeError, json.JSONDecodeError):
        return empty
    if not isinstance(data, dict):
        return empty
    out = {"0": [], "1": []}
    for side in ("0", "1"):
        rows = data.get(side, [])
        if not isinstance(rows, list):
            return empty
        cleaned = []
        for row in rows:
            if not isinstance(row, dict):
                continue
            name = row.get("name")
            code = row.get("deckContent")
            level = row.get("iaLevel")
            if not isinstance(name, str) or not isinstance(code, str):
                continue
            if isinstance(level, bool) or not isinstance(level, int):
                continue
            if level < 1 or level > 6 or not name.strip() or any(char.isspace() for char in code):
                continue
            cleaned.append({"name": name.strip(), "deckContent": code.strip(), "iaLevel": level})
        out[side] = cleaned[:8]
    return out


def render_decks(decks):
    body = {"0": decks.get("0", []), "1": decks.get("1", [])}
    return json.dumps(body, indent=2) + "\n"


def _base_save(payload, existing, catalog):
    values = existing.get("values", {})
    scenario_id = _require_text(payload.get("map"), "Map", 80)
    if " " in scenario_id or '"' in scenario_id:
        raise LobbyError("Map cannot contain spaces or quotes.")
    folded = "".join(scenario_id.split()).lower()
    if folded == "junglelaw" or scenario_id.startswith(("YOUR_", "REPLACE_WITH_")):
        raise LobbyError("Map must be a scenario ID from the list.")
    known = _scenario_index(catalog).get(scenario_id)
    if known is None and scenario_id != values.get("Map"):
        raise LobbyError("Map must be a scenario ID from the list.")

    server_name = _require_text(payload.get("serverName"), "Server name", 64)
    game_type = _keep_current(payload.get("gameType"), _current_int(values, "GameType"), MENU_GAME_TYPE)
    combat = _canonical_number(payload.get("combatRule"), 1, 2)
    if combat not in (1, 2):
        raise LobbyError("Combat rule must be Destruction or Conquest.")
    if known is not None:
        expected = int(known[1]["rule"])
        if combat != expected:
            label = "Destruction" if expected == 1 else "Conquest"
            raise LobbyError(f"That map is {label} only.")
    money = _keep_current(payload.get("initMoney"), _current_int(values, "InitMoney"), MENU_MONEY)
    time_limit = _keep_current(payload.get("timeLimit"), _current_int(values, "TimeLimit"), MENU_TIME)
    score = _keep_current(payload.get("scoreLimit"), _current_int(values, "ScoreLimit"), MENU_SCORE)
    income = _keep_current(payload.get("incomeRate"), _current_int(values, "IncomeRate"), MENU_INCOME)
    upkeep = _keep_current(payload.get("upkeep"), _current_int(values, "Upkeep"), MENU_UPKEEP)

    known_ids = {mod["id"] for mod in catalog_mods(catalog)}
    mod_list = _merge_mods(payload.get("mods"), values.get("ModList", ""), known_ids)
    posted_ids = [part.split("/", 1)[0] for part in mod_list.split("-") if part]
    mod_tags = _derive_tags(posted_ids, catalog, values.get("ModTagList", ""))
    if known is None:
        use_file = True
        base_players, base_team, base_min = 4, 2, 2
    else:
        group, scenario = known
        use_file = False
        base_players = int(scenario["players"])
        base_team = int(scenario["team"])
        base_min = 2 if base_players >= 2 else base_players
        pack = _pack_id(group)
        if pack and pack not in set(posted_ids):
            raise LobbyError("That map needs its workshop mod in Workshop Mod List.")
    if mod_list and not MOD_LIST.match(mod_list):
        raise LobbyError("Workshop mod list is not an id/version list.")
    if mod_tags and not MOD_TAGS.match(mod_tags):
        raise LobbyError("Workshop mod tags are not words joined with hyphens.")
    return {
        "values": values,
        "extras": existing.get("extras", []),
        "server_name": server_name,
        "game_type": game_type,
        "combat": combat,
        "money": money,
        "time_limit": time_limit,
        "score": score,
        "income": income,
        "upkeep": upkeep,
        "scenario_id": scenario_id,
        "mod_list": mod_list,
        "mod_tags": mod_tags,
        "use_file": use_file,
        "base_players": base_players,
        "base_team": base_team,
        "base_min": base_min,
    }


def _managed(base, players, team, minimum):
    managed = {
        "ServerName": base["server_name"],
        "NbMaxPlayer": str(players),
        "NbMinPlayer": str(minimum),
        "MaxTeamSize": str(team),
        "GameType": str(base["game_type"]),
        "CombatRule": str(base["combat"]),
        "Map": base["scenario_id"],
        "InitMoney": str(base["money"]),
        "TimeLimit": str(base["time_limit"]),
        "ScoreLimit": str(base["score"]),
        "IncomeRate": str(base["income"]),
        "Upkeep": str(base["upkeep"]),
    }
    if base["mod_list"]:
        managed["ModList"] = base["mod_list"]
    if base["mod_tags"]:
        managed["ModTagList"] = base["mod_tags"]
    return managed


def _seeded_values(values, delta=None):
    seeded = {}
    for key, default in SEEDED.items():
        if key == "DeltaMaxTeamSize" and delta is not None:
            seeded[key] = str(delta)
            continue
        current = values.get(key, default)
        if not str(current).isdigit():
            raise LobbyError("variables.ini has a line this page cannot keep.")
        seeded[key] = str(int(current))
    return seeded


def _validate_pvp(payload, existing, catalog):
    base = _base_save(payload, existing, catalog)
    values = base["values"]
    players = _choose_count(
        payload, "players", values, "NbMaxPlayer", base["use_file"], base["base_players"], 1, 20,
        "Max players must be a whole number.", "Max players must be from 1 to 20.",
    )
    team = _choose_count(
        payload, "team", values, "MaxTeamSize", base["use_file"], base["base_team"], 1, players,
        "Team size must be a whole number.", "Team size must be from 1 to the max player count.",
    )
    minimum = _choose_count(
        payload, "minPlayers", values, "NbMinPlayer", base["use_file"], base["base_min"], 1, players,
        "Minimum players must be a whole number.", "Minimum players must be from 1 to the max player count.",
    )
    managed = _managed(base, players, team, minimum)
    delta = None
    if "CoopVsAI" in values:
        raw = values["CoopVsAI"]
        if raw in ("1", "2"):
            managed["CoopVsAI"] = "0"
            delta = 0
        elif raw == "0":
            managed["CoopVsAI"] = "0"
        else:
            raise LobbyError("Setup must be PvP or PvE setup.")
    return managed, _seeded_values(values, delta), base["extras"], None


def _validate_pve(payload, existing, catalog):
    base = _base_save(payload, existing, catalog)
    humans = _player_count(
        payload.get("humans"), 1, 19,
        "Human players must be a whole number.", "Human players must be from 1 to 19.",
    )
    ai = _player_count(
        payload.get("ai"), 1, 19,
        "AI opponents must be a whole number.", "AI opponents must be from 1 to 19.",
    )
    if humans + ai > 20:
        raise LobbyError("Human players and AI opponents together must be at most 20.")
    side = _canonical_number(payload.get("humanSide"), 1, 2)
    decks = _validate_decks(payload.get("decks"), side)
    managed = _managed(base, humans + ai, max(humans, ai), humans)
    managed["CoopVsAI"] = str(side)
    return managed, _seeded_values(base["values"], abs(humans - ai)), base["extras"], decks


def validate_save(payload, existing, catalog):
    if _setup(payload) == "pve":
        return _validate_pve(payload, existing, catalog)
    return _validate_pvp(payload, existing, catalog)


def form_payload(existing, decks=None):
    values = existing.get("values", {}) if isinstance(existing, dict) else {}
    mod_list = values.get("ModList", "")
    mods = [part.split("/", 1)[0] for part in mod_list.split("-") if part] if mod_list else []
    body = {
        "serverName": values.get("ServerName", ""),
        "map": values.get("Map", ""),
        "gameType": values.get("GameType", "0"),
        "combatRule": values.get("CombatRule", "2"),
        "initMoney": values.get("InitMoney", "750"),
        "timeLimit": values.get("TimeLimit", "1200"),
        "scoreLimit": values.get("ScoreLimit", "2000"),
        "incomeRate": values.get("IncomeRate", "3"),
        "upkeep": values.get("Upkeep", "0"),
        "players": values.get("NbMaxPlayer", "4"),
        "team": values.get("MaxTeamSize", "2"),
        "minPlayers": values.get("NbMinPlayer", "2"),
        "mods": mods,
        "setup": "pvp",
    }
    if values.get("CoopVsAI") in ("1", "2"):
        humans, ai = counts_from_values(values)
        body["setup"] = "pve"
        body["humanSide"] = values["CoopVsAI"]
        body["humans"] = str(humans)
        body["ai"] = str(ai)
        body["decks"] = decks if isinstance(decks, dict) else {"0": [], "1": []}
    return body


def settings_changed(payload, existing, catalog, decks_on_disk=None):
    managed, seeded, extras, decks = validate_save(payload, existing, catalog)
    try:
        current, _, _, current_decks = validate_save(
            form_payload(existing, decks_on_disk), existing, catalog
        )
    except LobbyError:
        return True, managed, seeded, extras, decks
    return managed != current or decks != current_decks, managed, seeded, extras, decks


def render(managed, seeded, extras):
    order = [
        "ServerName",
        "NbMaxPlayer",
        "NbMinPlayer",
        "MaxTeamSize",
        "GameType",
        "CoopVsAI",
        "CombatRule",
        "Map",
        "ModList",
        "ModTagList",
        "MapRotationType",
        "InitMoney",
        "TimeLimit",
        "ScoreLimit",
        "WarmupCountdown",
        "LoadingTimeMax",
        "DeploiementTimeMax",
        "DebriefingTimeMax",
        "DeltaMaxTeamSize",
        "IncomeRate",
        "Upkeep",
        "AllowObservers",
        "ObserverDelay",
    ]
    combined = dict(managed)
    combined.update(seeded)
    lines = [f"{key} = {combined[key]}" for key in order if key in combined]
    for key, value in extras:
        if key not in combined:
            lines.append(f"{key} = {value}")
    return "\n".join(lines) + "\n"


def publish(settings_dir, text):
    settings = Path(settings_dir)
    dest = settings / "variables.ini"
    if dest.is_symlink():
        dest.unlink()
    if dest.is_dir():
        raise LobbyError("variables.ini is a directory, so it was not replaced.")
    stage = Path(tempfile.mkdtemp(prefix=".warhost-stage.", dir=settings))
    os.chmod(stage, 0o700)
    try:
        staged = stage / "variables.ini"
        staged.write_text(text)
        os.chmod(staged, 0o600)
        if dest.is_file():
            backup = stage / "variables.ini.bak"
            shutil.copyfile(dest, backup)
            os.chmod(backup, 0o600)
            os.replace(backup, settings / "variables.ini.bak")
            os.chmod(settings / "variables.ini.bak", 0o600)
        os.replace(staged, dest)
        os.chmod(dest, 0o600)
    finally:
        shutil.rmtree(stage, ignore_errors=True)


def publish_params(settings_dir, text):
    settings = Path(settings_dir)
    dest = settings / "params_for_ai.json"
    if dest.is_symlink():
        dest.unlink()
    if dest.is_dir():
        raise LobbyError("params_for_ai.json is a directory, so it was not replaced.")
    stage = Path(tempfile.mkdtemp(prefix=".warhost-stage.", dir=settings))
    os.chmod(stage, 0o700)
    try:
        staged = stage / "params_for_ai.json"
        staged.write_text(text)
        os.chmod(staged, 0o600)
        os.replace(staged, dest)
        os.chmod(dest, 0o600)
    finally:
        shutil.rmtree(stage, ignore_errors=True)
