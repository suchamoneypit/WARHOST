"""Validate a lobby page save and replace variables.ini. Never reads login.ini."""

import os
import re
import shutil
import tempfile
from pathlib import Path

MENU_UPKEEP = (0, 5, 7)
MENU_MONEY = (500, 1000, 1500, 2000, 2500, 3000)
MENU_TIME = (1200, 1800, 2400, 3600, 0)
MENU_SCORE = (1000, 2000, 4000)
MENU_INCOME = (0, 1, 2, 3, 4, 5)
MENU_GAME_TYPE = (0, 1, 2)

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


def _current_int(values, key):
    text = values.get(key)
    if text is None or not str(text).isdigit():
        return None
    number = int(text)
    if str(number) != str(text):
        return None
    return number


def validate_save(payload, existing, catalog):
    if not isinstance(payload, dict):
        raise LobbyError("The lobby page sent an unreadable save.")
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
    money = _keep_current(payload.get("initMoney"), _current_int(values, "InitMoney"), MENU_MONEY)
    time_limit = _keep_current(payload.get("timeLimit"), _current_int(values, "TimeLimit"), MENU_TIME)
    score = _keep_current(payload.get("scoreLimit"), _current_int(values, "ScoreLimit"), MENU_SCORE)
    income = _keep_current(payload.get("incomeRate"), _current_int(values, "IncomeRate"), MENU_INCOME)
    upkeep = _keep_current(payload.get("upkeep"), _current_int(values, "Upkeep"), MENU_UPKEEP)

    if known is None:
        players = _canonical_number(values.get("NbMaxPlayer", "4"), 1, 20)
        team = _canonical_number(values.get("MaxTeamSize", "2"), 1, players)
        minimum = _canonical_number(values.get("NbMinPlayer", "2"), 1, players)
        mod_list = values.get("ModList", "")
        mod_tags = values.get("ModTagList", "")
    else:
        group, scenario = known
        players = int(scenario["players"])
        team = int(scenario["team"])
        minimum = 2 if players >= 2 else players
        mod_list = group["modList"]
        mod_tags = group["modTags"]
    if mod_list and not MOD_LIST.match(mod_list):
        raise LobbyError("Workshop mod list is not an id/version list.")
    if mod_tags and not MOD_TAGS.match(mod_tags):
        raise LobbyError("Workshop mod tags are not words joined with hyphens.")

    managed = {
        "ServerName": server_name,
        "NbMaxPlayer": str(players),
        "NbMinPlayer": str(minimum),
        "MaxTeamSize": str(team),
        "GameType": str(game_type),
        "CombatRule": str(combat),
        "Map": scenario_id,
        "InitMoney": str(money),
        "TimeLimit": str(time_limit),
        "ScoreLimit": str(score),
        "IncomeRate": str(income),
        "Upkeep": str(upkeep),
    }
    if mod_list:
        managed["ModList"] = mod_list
    if mod_tags:
        managed["ModTagList"] = mod_tags
    seeded = {}
    for key, default in SEEDED.items():
        current = values.get(key, default)
        if not str(current).isdigit():
            raise LobbyError("variables.ini has a line this page cannot keep.")
        seeded[key] = str(int(current))
    return managed, seeded, existing.get("extras", [])


def render(managed, seeded, extras):
    order = [
        "ServerName",
        "NbMaxPlayer",
        "NbMinPlayer",
        "MaxTeamSize",
        "GameType",
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


def _none(value):
    return value.strip().lower() == "none"


def _pin_mods(mod_list, catalog):
    if not mod_list or _none(mod_list):
        return ""
    pins = {}
    for group in catalog["groups"]:
        if not group["modList"]:
            continue
        pack_id = group["modList"].split("/", 1)[0]
        pins[pack_id] = group["modList"]
    resolved = []
    for entry in mod_list.split("-"):
        if "/" in entry:
            resolved.append(entry)
        elif entry in pins:
            resolved.append(pins[entry])
        else:
            resolved.append(entry)
    return "-".join(resolved)


def reset_from_form(env, catalog):
    name = _require_text(env.get("SERVER_NAME") or "WARHOST - Hesse 2v2", "Server name", 64)
    scenario_id = _require_text(env.get("MAP") or "_2x2_Hesse_2vs2_CONQ", "Map", 80)
    if " " in scenario_id or '"' in scenario_id:
        raise LobbyError("Map cannot contain spaces or quotes.")
    folded = "".join(scenario_id.split()).lower()
    if folded == "junglelaw" or scenario_id.startswith(("YOUR_", "REPLACE_WITH_")):
        raise LobbyError("Map must be a scenario ID from the list.")
    players = _canonical_number(env.get("NB_MAX_PLAYER") or "4", 1, 20)
    minimum = _canonical_number(env.get("NB_MIN_PLAYER") or "2", 1, players)
    team = _canonical_number(env.get("MAX_TEAM_SIZE") or "2", 1, players)
    combat = _canonical_number(env.get("COMBAT_RULE") or "2", 1, 2)
    if combat not in (1, 2):
        raise LobbyError("Combat rule must be Destruction or Conquest.")
    mod_list = _pin_mods(env.get("MOD_LIST") or "", catalog)
    mod_tags = env.get("MOD_TAG_LIST") or ""
    if _none(mod_tags):
        mod_tags = ""
    if mod_list and not MOD_LIST.match(mod_list):
        raise LobbyError("Workshop mod list is not an id/version list.")
    if mod_tags and not MOD_TAGS.match(mod_tags):
        raise LobbyError("Workshop mod tags are not words joined with hyphens.")
    managed = {
        "ServerName": name,
        "NbMaxPlayer": str(players),
        "NbMinPlayer": str(minimum),
        "MaxTeamSize": str(team),
        "GameType": "0",
        "CombatRule": str(combat),
        "Map": scenario_id,
        "InitMoney": "750",
        "TimeLimit": "1200",
        "ScoreLimit": "2000",
        "IncomeRate": "3",
        "Upkeep": "0",
    }
    if mod_list:
        managed["ModList"] = mod_list
    if mod_tags:
        managed["ModTagList"] = mod_tags
    return render(managed, dict(SEEDED), [])


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
