#!/bin/sh
# Exercises the lobby page without starting warno-server.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
WORKDIR=$(mktemp -d)
PAGE_PID=
ROOT_PAGE_PID=
ROOT_RUN=
SUPERVISOR_PID=
cleanup() {
  if [ -n "${SUPERVISOR_PID:-}" ]; then
    kill "$SUPERVISOR_PID" 2>/dev/null || true
    wait "$SUPERVISOR_PID" 2>/dev/null || true
  fi
  if [ -n "${PAGE_PID:-}" ]; then
    kill -- "-$PAGE_PID" 2>/dev/null || kill "$PAGE_PID" 2>/dev/null || true
    wait "$PAGE_PID" 2>/dev/null || true
  fi
  if [ -n "${ROOT_PAGE_PID:-}" ]; then
    sudo kill -- "-$ROOT_PAGE_PID" 2>/dev/null || sudo kill "$ROOT_PAGE_PID" 2>/dev/null || true
  fi
  if [ -n "${ROOT_RUN:-}" ]; then
    sudo rm -rf "$ROOT_RUN"
  fi
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  if [ -f "${WORKDIR}/page.log" ]; then
    printf '%s\n' '--- page log ---' >&2
    cat "${WORKDIR}/page.log" >&2
  fi
  if [ -f "${WORKDIR}/root-drop.log" ]; then
    printf '%s\n' '--- root drop log ---' >&2
    cat "${WORKDIR}/root-drop.log" >&2
  fi
  if [ -f "${WORKDIR}/root-user.log" ]; then
    printf '%s\n' '--- root user log ---' >&2
    cat "${WORKDIR}/root-user.log" >&2
  fi
  exit 1
}

capture_code() {
  _body=$1
  shift
  code=$(curl -sS -o "$_body" -w '%{http_code}' "$@") || fail "lobby page request failed"
}

python3 "${ROOT}/webui/make_catalog.py" --check
python3 - "$ROOT" << 'PY' || fail "workshop author credit check failed"
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
data = json.loads((root / "webui/scenarios.json").read_text())
expected = {
    "3811913066": "Zim",
    "3363584349": "Silver",
    "3474588989": "Kel",
    "3705706772": "Kel",
    "3415339374": "Kel",
    "3762638679": "Silver",
    "3595948209": "BiometricNuke",
    "3388575848": "etouf fement",
}
found = {}
for group in data["groups"]:
    mod_id = (group.get("modList") or "").split("/", 1)[0]
    author = group.get("author") or ""
    if not mod_id:
        if str(author).strip():
            raise SystemExit("base game has an author")
        continue
    found[mod_id] = author
for mod in data["mods"]:
    found[str(mod["id"])] = mod.get("author") or ""
if found != expected:
    raise SystemExit("workshop authors %s" % found)
html = (root / "webui/index.html").read_text()
start = html.index("function creditText")
body = html[start:html.index("function renderChecks", start)]
if 'return text ? "by " + text : "";' not in body:
    raise SystemExit("creditText does not omit a blank author")
if "creditText(row.author)" not in html or 'className = "mod-author"' not in html:
    raise SystemExit("checklist does not place the author next to the name")
if 'author: found ? found.author : ""' not in html:
    raise SystemExit("an unknown workshop id would invent an author")
PY
printf 'ok scenario catalog matches the README\n'
printf 'ok workshop authors sit next to the checklist names\n'

settings="${WORKDIR}/settings"
mkdir -p "$settings"
cat > "${settings}/login.ini" << 'EOF'
login="host-login"
dedicated_key="host-key-value"
EOF
chmod 600 "${settings}/login.ini"
cat > "${settings}/variables.ini" << 'EOF'
ServerName = WARHOST - Hesse 2v2
NbMaxPlayer = 4
NbMinPlayer = 2
MaxTeamSize = 2
GameType = 0
CombatRule = 2
Map = _2x2_Hesse_2vs2_CONQ
MapRotationType = 0
InitMoney = 750
TimeLimit = 1200
ScoreLimit = 2000
WarmupCountdown = 60
LoadingTimeMax = 120
DeploiementTimeMax = 120
DebriefingTimeMax = 60
DeltaMaxTeamSize = 0
IncomeRate = 3
Upkeep = 0
AllowObservers = 1
ObserverDelay = 120
EOF
checksum=$(cksum "${settings}/variables.ini")

PORT=39521
export SETTINGS_DIR="$settings"
export WARHOST_WEB_PORT="$PORT"
export EXPOSEDPORT=38521
export SERVER_NAME="WARHOST - Hesse 2v2"
export MAP=_2x2_Hesse_2vs2_CONQ
export NB_MAX_PLAYER=4
export NB_MIN_PLAYER=2
export MAX_TEAM_SIZE=2
export COMBAT_RULE=2
setsid env -u EUGEN_LOGIN -u EUGEN_DEDICATED_KEY \
  SETTINGS_DIR="$settings" \
  WARHOST_WEB_PORT="$PORT" \
  EXPOSEDPORT=38521 \
  SERVER_NAME="WARHOST - Hesse 2v2" \
  MAP=_2x2_Hesse_2vs2_CONQ \
  NB_MAX_PLAYER=4 \
  NB_MIN_PLAYER=2 \
  MAX_TEAM_SIZE=2 \
  COMBAT_RULE=2 \
  python3 "${ROOT}/webui/server.py" --serve >"${WORKDIR}/page.log" 2>&1 &
PAGE_PID=$!

i=0
while [ "$i" -lt 50 ]; do
  if [ -f "${settings}/.warhost-webui.ready" ]; then
    break
  fi
  i=$((i + 1))
  sleep 0.05
done
[ -f "${settings}/.warhost-webui.ready" ] || fail "lobby page did not become ready"

base="http://127.0.0.1:${PORT}"
same='{"action":"restart","serverName":"WARHOST - Hesse 2v2","map":"_2x2_Hesse_2vs2_CONQ","gameType":0,"combatRule":2,"initMoney":750,"timeLimit":1200,"scoreLimit":2000,"incomeRate":3,"upkeep":0,"players":4,"team":2,"minPlayers":2,"mods":[]}'
capture_code "${WORKDIR}/body.txt" \
  -H 'Origin: http://evil.example' \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data "$same" \
  "${base}/api/lobby"
[ "$code" = "403" ] || fail "cross-site restart returned ${code}"
[ "$(cksum "${settings}/variables.ini")" = "$checksum" ] || fail "cross-site restart changed variables.ini"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data "$same" \
  "${base}/api/lobby"
[ "$code" = "409" ] || fail "unchanged restart returned ${code}"
python3 -c 'import json,sys; body=json.load(open(sys.argv[1])); raise SystemExit(0 if body.get("error")=="No settings have changed, are you sure you want to restart the container?" else 1)' "${WORKDIR}/body.txt" || fail "unchanged restart did not use the warning"
python3 -c 'import json,sys; body=json.load(open(sys.argv[1])); assert body.get("confirmUnchanged") is True' "${WORKDIR}/body.txt" || fail "unchanged restart did not ask for confirmation"
[ "$(cksum "${settings}/variables.ini")" = "$checksum" ] || fail "unchanged restart changed variables.ini"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"restart","confirmUnchanged":true,"serverName":"WARHOST - Hesse 2v2","map":"_2x2_Hesse_2vs2_CONQ","gameType":0,"combatRule":2,"initMoney":750,"timeLimit":1200,"scoreLimit":2000,"incomeRate":3,"upkeep":0,"players":4,"team":2,"minPlayers":2,"mods":[]}' \
  "${base}/api/lobby"
[ "$code" = "200" ] || fail "confirmed unchanged restart returned ${code}"
python3 -c 'import json,sys; body=json.load(open(sys.argv[1])); assert body["restarted"] is False and body["changed"] is False' "${WORKDIR}/body.txt" || fail "confirmed unchanged restart claimed a restart"
[ "$(cksum "${settings}/variables.ini")" = "$checksum" ] || fail "confirmed unchanged restart changed variables.ini"
grep -q 'This page cannot restart the container. Restart it in Unraid.' "${WORKDIR}/body.txt" || fail "confirmed unchanged restart hid the limitation"

ready_flag="${WORKDIR}/supervisor-ready"
rm -f "$ready_flag"
python3 -c 'import os,sys; os.execv(sys.executable, ["entrypoint-unraid.sh","-c","import pathlib,signal,sys,time; signal.signal(signal.SIGUSR1, lambda *a: sys.exit(0)); pathlib.Path(sys.argv[1]).write_text(\"up\"); time.sleep(60)", sys.argv[1]])' "$ready_flag" &
SUPERVISOR_PID=$!
i=0
while [ "$i" -lt 50 ]; do
  if [ -f "$ready_flag" ]; then
    break
  fi
  i=$((i + 1))
  sleep 0.05
done
[ -f "$ready_flag" ] || fail "restart target did not start"
printf '%s\n' "$SUPERVISOR_PID" > "${settings}/.warhost-supervisor.pid"
capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"restart","confirmUnchanged":true,"serverName":"WARHOST - Hesse 2v2","map":"_2x2_Hesse_2vs2_CONQ","gameType":0,"combatRule":2,"initMoney":750,"timeLimit":1200,"scoreLimit":2000,"incomeRate":3,"upkeep":0,"players":4,"team":2,"minPlayers":2,"mods":[]}' \
  "${base}/api/lobby"
[ "$code" = "200" ] || fail "signaled restart returned ${code}"
python3 -c 'import json,sys; body=json.load(open(sys.argv[1])); assert body["restarted"] is True and body["changed"] is False' "${WORKDIR}/body.txt" || fail "signaled restart did not report the signal"
[ "$(cksum "${settings}/variables.ini")" = "$checksum" ] || fail "signaled restart changed variables.ini"
if kill -0 "$SUPERVISOR_PID" 2>/dev/null; then
  fail "restart signal left the supervisor running"
fi
wait "$SUPERVISOR_PID" 2>/dev/null || true
SUPERVISOR_PID=
kill -0 "$PAGE_PID" || fail "restart signal stopped the WebUI"
curl -fsS -o /dev/null "${base}/" || fail "WebUI exited when it signaled a restart"
rm -f "${settings}/.warhost-supervisor.pid"
capture_code "${WORKDIR}/body.txt" \
  -H 'Origin: http://evil.example' \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"x","map":"_2x2_Hesse_2vs2_CONQ","gameType":0,"combatRule":2,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0}' \
  "${base}/api/lobby"
[ "$code" = "403" ] || fail "cross-site save returned ${code}"
[ "$(cksum "${settings}/variables.ini")" = "$checksum" ] || fail "cross-site save changed variables.ini"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"x","map":"not-a-map","gameType":0,"combatRule":2,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0}' \
  "${base}/api/lobby"
[ "$code" = "400" ] || fail "rejected save returned ${code}"
[ "$(cksum "${settings}/variables.ini")" = "$checksum" ] || fail "rejected save changed variables.ini"
grep -qx 'InitMoney = 750' "${settings}/variables.ini" || fail "rejected save changed starting resources"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"x","map":"_2x2_Hesse_2vs2_CONQ","gameType":0,"combatRule":1,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0,"mods":[]}' \
  "${base}/api/lobby"
[ "$code" = "400" ] || fail "conquest map with destruction returned ${code}"
grep -q 'That map is Conquest only.' "${WORKDIR}/body.txt" || fail "conquest map did not name its rule"
[ "$(cksum "${settings}/variables.ini")" = "$checksum" ] || fail "rejected combat rule changed variables.ini"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"Saved Lobby","map":"RDPort_JungleLaw_2v2_CONQ","gameType":1,"combatRule":2,"initMoney":1500,"timeLimit":2400,"scoreLimit":4000,"incomeRate":5,"upkeep":5,"mods":[]}' \
  "${base}/api/lobby"
[ "$code" = "400" ] || fail "modded map without a workshop id returned ${code}"
[ "$(cksum "${settings}/variables.ini")" = "$checksum" ] || fail "rejected modded map changed variables.ini"
grep -q 'That map needs its workshop mod in Workshop Mod List.' "${WORKDIR}/body.txt" || fail "rejected modded map did not name the workshop list"

python3 - << PY
from pathlib import Path
path = Path("${settings}/variables.ini")
text = path.read_text()
needle = "Map = _2x2_Hesse_2vs2_CONQ\n"
insert = needle + "ModList = 3811913066/27-3474588989/14\nModTagList = Maps-Scenarios\n"
if needle not in text:
    raise SystemExit("map line missing before mod insert")
path.write_text(text.replace(needle, insert, 1))
PY

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"Saved Lobby","map":"RDPort_JungleLaw_2v2_CONQ","gameType":1,"combatRule":2,"initMoney":1500,"timeLimit":2400,"scoreLimit":4000,"incomeRate":5,"upkeep":5,"mods":["3811913066","3474588989"]}' \
  "${base}/api/lobby"
[ "$code" = "200" ] || fail "save returned ${code}"
grep -qx 'ServerName = Saved Lobby' "${settings}/variables.ini" || fail "save did not write the server name"
grep -qx 'Map = RDPort_JungleLaw_2v2_CONQ' "${settings}/variables.ini" || fail "save did not write the map"
grep -qx 'ModList = 3811913066-3474588989' "${settings}/variables.ini" || fail "save did not write bare workshop ids"
grep -qx 'ModTagList = Maps-Scenarios' "${settings}/variables.ini" || fail "save did not derive the mod tags"
grep -qx 'GameType = 1' "${settings}/variables.ini" || fail "save did not write opposition"
grep -qx 'InitMoney = 1500' "${settings}/variables.ini" || fail "save did not write starting resources"
grep -qx 'TimeLimit = 2400' "${settings}/variables.ini" || fail "save did not write the time limit"
grep -qx 'IncomeRate = 5' "${settings}/variables.ini" || fail "save did not write income"
grep -qx 'Upkeep = 5' "${settings}/variables.ini" || fail "save did not write command and control"
grep -qx 'NbMaxPlayer = 4' "${settings}/variables.ini" || fail "save did not set the usual player count"
grep -qx 'AllowObservers = 1' "${settings}/variables.ini" || fail "save dropped a seeded setting"
grep -qx 'ServerName = WARHOST - Hesse 2v2' "${settings}/variables.ini.bak" || fail "save did not keep a backup"
grep -qx 'dedicated_key="host-key-value"' "${settings}/login.ini" || fail "save changed login.ini"

curl -fsS "${base}/" > "${WORKDIR}/page.html" || fail "lobby page did not load"
curl -fsS "${base}/api/lobby" > "${WORKDIR}/state.json" || fail "lobby state did not load"
if grep -F 'host-key-value' "${WORKDIR}/page.html" "${WORKDIR}/state.json" "${WORKDIR}/page.log" >/dev/null; then
  fail "lobby page exposed the dedicated key"
fi
grep -q 'Scenic view' "${WORKDIR}/page.html" || fail "page is missing the scenic slot"
grep -q 'Tactical zones' "${WORKDIR}/page.html" || fail "page is missing the tactical slot"
grep -q 'Map list (scenario ID list)' "${WORKDIR}/page.html" || fail "page is missing the map list heading"
grep -q 'Save and restart' "${WORKDIR}/page.html" || fail "page is missing Save and restart"
grep -q 'id="players"' "${WORKDIR}/page.html" || fail "page is missing max players"
grep -q 'id="team"' "${WORKDIR}/page.html" || fail "page is missing team size"
grep -q 'id="minPlayers"' "${WORKDIR}/page.html" || fail "page is missing minimum players"
grep -q 'presetLimits(scenario)' "${WORKDIR}/page.html" || fail "picking a map does not fill player limits"
python3 - "${WORKDIR}/page.html" << 'PY' || fail "player limits are locked"
import sys
from pathlib import Path
html = Path(sys.argv[1]).read_text()
for field in ("players", "team", "minPlayers"):
    start = html.index(f'id="{field}"')
    tag = html[html.rindex("<input", 0, start):html.index(">", start) + 1]
    if "disabled" in tag or "readonly" in tag:
        raise SystemExit(tag)
PY
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["map"]=="RDPort_JungleLaw_2v2_CONQ"; assert d["modList"]=="3811913066-3474588989"; assert d["modTags"]=="Maps-Scenarios"' "${WORKDIR}/state.json" || fail "state did not return the saved map"
kill -HUP "$PAGE_PID" || fail "could not signal the lobby page"
curl -fsS -o /dev/null "${base}/" || fail "lobby page exited on hangup"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"Saved Lobby","map":"_2x2_Hesse_2vs2_CONQ","gameType":0,"combatRule":2,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0,"mods":["3811913066","3474588989"]}' \
  "${base}/api/lobby"
[ "$code" = "200" ] || fail "base-game save returned ${code}"
grep -qx 'Map = _2x2_Hesse_2vs2_CONQ' "${settings}/variables.ini" || fail "base-game save did not write the map"
grep -qx 'ModList = 3811913066-3474588989' "${settings}/variables.ini" || fail "base-game save dropped the workshop mod list"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"Saved Lobby","map":"_2x2_Hesse_2vs2_CONQ","gameType":0,"combatRule":2,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0,"mods":["999000111","3811913066"]}' \
  "${base}/api/lobby"
[ "$code" = "400" ] || fail "unknown workshop id returned ${code}"
grep -qx 'ModList = 3811913066-3474588989' "${settings}/variables.ini" || fail "rejected workshop id changed the mod list"

python3 - << PY
from pathlib import Path
path = Path("${settings}/variables.ini")
text = path.read_text()
text = text.replace("ModList = 3811913066-3474588989\n", "ModList = 999000111/3-3811913066/27\n", 1)
text = text.replace("ModTagList = Maps-Scenarios\n", "ModTagList = Custom-Tags\n", 1)
path.write_text(text)
PY
capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"Saved Lobby","map":"_2x2_Hesse_2vs2_CONQ","gameType":0,"combatRule":2,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0,"mods":["999000111"]}' \
  "${base}/api/lobby"
[ "$code" = "200" ] || fail "unknown id save returned ${code}"
grep -qx 'ModList = 999000111/3' "${settings}/variables.ini" || fail "save did not keep the unknown workshop pin"
grep -qx 'ModTagList = Custom-Tags' "${settings}/variables.ini" || fail "unknown-only save did not keep the previous tags"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"Saved Lobby","map":"_2x2_Hesse_2vs2_CONQ","gameType":0,"combatRule":2,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0,"mods":["3388575848"]}' \
  "${base}/api/lobby"
[ "$code" = "200" ] || fail "flames save returned ${code}"
grep -qx 'ModList = 3388575848' "${settings}/variables.ini" || fail "flames save did not write the bare id"
grep -qx 'ModTagList = Gameplay-Interface' "${settings}/variables.ini" || fail "flames save did not use its tags"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"Saved Lobby","map":"RDPort_JungleLaw_2v2_CONQ","gameType":0,"combatRule":2,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0,"mods":["3811913066","3388575848","3595948209"]}' \
  "${base}/api/lobby"
[ "$code" = "200" ] || fail "combined mod save returned ${code}"
grep -qx 'ModList = 3388575848-3811913066-3595948209' "${settings}/variables.ini" || fail "combined save did not keep the existing id first"
grep -qx 'ModTagList = Gameplay-Interface-Maps-Scenarios-Sound' "${settings}/variables.ini" || fail "combined save did not union the tags"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"reset"}' \
  "${base}/api/lobby"
[ "$code" = "400" ] || fail "reset returned ${code}"
grep -qx 'ModList = 3388575848-3811913066-3595948209' "${settings}/variables.ini" || fail "reset changed the lobby file"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"Saved Lobby","map":"_2x3_Death_Row_2vs2_DEST","gameType":0,"combatRule":1,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0,"mods":[]}' \
  "${base}/api/lobby"
[ "$code" = "200" ] || fail "destruction save returned ${code}"
grep -qx 'CombatRule = 1' "${settings}/variables.ini" || fail "destruction save did not write the combat rule"
grep -qx 'Map = _2x3_Death_Row_2vs2_DEST' "${settings}/variables.ini" || fail "destruction save did not write the map"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"restart","serverName":"Saved Lobby","map":"_2x3_Death_Row_2vs2_DEST","gameType":0,"combatRule":1,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0,"players":2,"team":1,"minPlayers":2,"mods":[]}' \
  "${base}/api/lobby"
[ "$code" = "409" ] || fail "changed restart without confirmation returned ${code}"
grep -q 'Save these settings and restart the container? The current match will stop.' "${WORKDIR}/body.txt" || fail "changed restart did not ask to confirm"
grep -qx 'NbMaxPlayer = 4' "${settings}/variables.ini" || fail "unconfirmed restart wrote player limits"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"restart","confirmRestart":true,"serverName":"Saved Lobby","map":"_2x3_Death_Row_2vs2_DEST","gameType":0,"combatRule":1,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0,"players":2,"team":1,"minPlayers":2,"mods":[]}' \
  "${base}/api/lobby"
[ "$code" = "200" ] || fail "1v1 restart returned ${code}"
python3 -c 'import json,sys; body=json.load(open(sys.argv[1])); assert body["changed"] is True and body["restarted"] is False' "${WORKDIR}/body.txt" || fail "1v1 restart did not save without a supervisor"
grep -qx 'NbMaxPlayer = 2' "${settings}/variables.ini" || fail "1v1 restart did not write max players"
grep -qx 'MaxTeamSize = 1' "${settings}/variables.ini" || fail "1v1 restart did not write team size"
grep -qx 'NbMinPlayer = 2' "${settings}/variables.ini" || fail "1v1 restart did not write minimum players"
grep -qx 'Map = _2x3_Death_Row_2vs2_DEST' "${settings}/variables.ini" || fail "1v1 restart changed the map"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"restart","serverName":"Saved Lobby","map":"_2x3_Death_Row_2vs2_DEST","gameType":0,"combatRule":1,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0,"players":2,"team":1,"minPlayers":2,"mods":[]}' \
  "${base}/api/lobby"
[ "$code" = "409" ] || fail "saved 1v1 was still treated as changed"
grep -q 'No settings have changed, are you sure you want to restart the container?' "${WORKDIR}/body.txt" || fail "saved 1v1 did not warn before restart"
grep -qx 'NbMaxPlayer = 2' "${settings}/variables.ini" || fail "unchanged 1v1 warning rewrote max players"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"Saved Lobby","map":"_2x3_Death_Row_2vs2_DEST","gameType":0,"combatRule":1,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0,"players":8,"team":4,"minPlayers":2,"mods":[]}' \
  "${base}/api/lobby"
[ "$code" = "200" ] || fail "4v4 override returned ${code}"
grep -qx 'NbMaxPlayer = 8' "${settings}/variables.ini" || fail "4v4 override did not write max players"
grep -qx 'MaxTeamSize = 4' "${settings}/variables.ini" || fail "4v4 override did not write team size"
grep -qx 'NbMinPlayer = 2' "${settings}/variables.ini" || fail "4v4 override did not write minimum players"
grep -qx 'Map = _2x3_Death_Row_2vs2_DEST' "${settings}/variables.ini" || fail "4v4 override changed the map"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"Saved Lobby","map":"_2x3_Death_Row_2vs2_DEST","gameType":0,"combatRule":1,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0,"players":2,"team":3,"minPlayers":2,"mods":[]}' \
  "${base}/api/lobby"
[ "$code" = "400" ] || fail "team size above max players returned ${code}"
grep -qx 'NbMaxPlayer = 8' "${settings}/variables.ini" || fail "rejected team size changed max players"

capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"Saved Lobby","map":"_2x3_Death_Row_2vs2_DEST","gameType":0,"combatRule":1,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0,"players":21,"team":4,"minPlayers":2,"mods":[]}' \
  "${base}/api/lobby"
[ "$code" = "400" ] || fail "max players above 20 returned ${code}"
grep -qx 'NbMaxPlayer = 8' "${settings}/variables.ini" || fail "rejected max players changed the file"

outside="${WORKDIR}/outside.ini"
printf 'secret-target\n' > "$outside"
ln -sf "$outside" "${settings}/variables.ini"
capture_code "${WORKDIR}/body.txt" \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"Saved Lobby","map":"_2x2_Hesse_2vs2_CONQ","gameType":0,"combatRule":2,"initMoney":500,"timeLimit":1200,"scoreLimit":1000,"incomeRate":0,"upkeep":0,"mods":[]}' \
  "${base}/api/lobby"
[ "$code" = "200" ] || fail "symlink save returned ${code}"
[ ! -L "${settings}/variables.ini" ] || fail "save followed a symlink"
grep -qx 'secret-target' "$outside" || fail "save wrote through a symlink"
grep -qx 'Map = _2x2_Hesse_2vs2_CONQ' "${settings}/variables.ini" || fail "symlink save did not replace variables.ini"

printf 'ok lobby page saves and rejects\n'

if sudo -n true 2>/dev/null; then
  sudo useradd --system --user-group --no-create-home --shell /usr/sbin/nologin warhost-web 2>/dev/null || true
  getent passwd warhost-web >/dev/null || fail "warhost-web user was not created"
  root_settings="${WORKDIR}/root-settings"
  mkdir -p "$root_settings"
  printf 'ServerName = WARHOST - Hesse 2v2\nMap = _2x2_Hesse_2vs2_CONQ\n' > "${root_settings}/variables.ini"
  ROOT_RUN="${ROOT}/webui/run"

  # sudo stays in the foreground until the page answers. setsid puts the
  # server in its own session, so sudo's exit does not hang the page up.
  start_root_server() {
    _log=$1
    _port=$2
    shift 2
    : > "$_log"
    sudo -n "$@" sh -c '
      setsid python3 "$1" --serve >"$2" 2>&1 </dev/null &
      ready=$3
      port=$4
      i=0
      while [ "$i" -lt 50 ]; do
        if [ -f "$ready" ] && grep -qx "$port" "$ready"; then
          curl -fsS -o /dev/null "http://127.0.0.1:${port}/" && exit 0
        fi
        i=$((i + 1))
        sleep 0.05
      done
      exit 1
    ' sh "${ROOT}/webui/server.py" "$_log" "${root_settings}/.warhost-webui.ready" "$_port" \
      || return $?
  }

  start_root_server "${WORKDIR}/root-drop.log" 39522 \
    env -u EUGEN_LOGIN -u EUGEN_DEDICATED_KEY \
    SETTINGS_DIR="$root_settings" \
    WARHOST_WEB_PORT=39522 \
    WARHOST_WEBUI_DROP_FAIL=1 \
    EXPOSEDPORT=38522 \
    || fail "root lobby page did not become ready after a failed privilege drop"
  ROOT_PAGE_PID=$(sudo cat "${root_settings}/.warhost-webui.pid") || fail "lobby page did not write its pid"
  capture_code "${WORKDIR}/root-body.txt" "http://127.0.0.1:39522/"
  [ "$code" = "200" ] || fail "failed privilege drop returned ${code}"
  grep -q 'stayed root' "${WORKDIR}/root-drop.log" || fail "failed privilege drop did not warn"
  uid=$(ps -o uid= -p "$ROOT_PAGE_PID" | tr -d ' ')
  [ "$uid" = "0" ] || fail "failed privilege drop was not still root"
  sudo kill -- "-$ROOT_PAGE_PID" 2>/dev/null || sudo kill "$ROOT_PAGE_PID" 2>/dev/null || true
  i=0
  while [ "$i" -lt 20 ] && ps -p "$ROOT_PAGE_PID" >/dev/null 2>&1; do
    i=$((i + 1))
    sleep 0.05
  done
  ROOT_PAGE_PID=
  sudo rm -f "${root_settings}/.warhost-webui.ready" "${root_settings}/.warhost-webui.pid" "${root_settings}/.warhost-webui.log"

  start_root_server "${WORKDIR}/root-user.log" 39523 \
    env -u EUGEN_LOGIN -u EUGEN_DEDICATED_KEY \
    SETTINGS_DIR="$root_settings" \
    WARHOST_WEB_PORT=39523 \
    EXPOSEDPORT=38523 \
    || fail "root lobby page did not become ready"
  ROOT_PAGE_PID=$(sudo cat "${root_settings}/.warhost-webui.pid") || fail "lobby page did not write its pid"
  capture_code "${WORKDIR}/root-body.txt" "http://127.0.0.1:39523/"
  [ "$code" = "200" ] || fail "dropped lobby page returned ${code}"
  web_uid=$(id -u warhost-web)
  uid=$(ps -o uid= -p "$ROOT_PAGE_PID" | tr -d ' ')
  [ "$uid" = "$web_uid" ] || fail "lobby page did not drop to warhost-web"
  if grep -F 'host-key-value' "${WORKDIR}/root-drop.log" "${WORKDIR}/root-user.log" >/dev/null; then
    fail "root lobby page log contained a dedicated key"
  fi
  sudo kill -- "-$ROOT_PAGE_PID" 2>/dev/null || sudo kill "$ROOT_PAGE_PID" 2>/dev/null || true
  ROOT_PAGE_PID=
  launch_settings="${WORKDIR}/launch-settings"
  mkdir -p "$launch_settings"
  printf 'ServerName = WARHOST - Hesse 2v2\n' > "${launch_settings}/variables.ini"
  sudo -n env SETTINGS_DIR="$launch_settings" EXPOSEDPORT=38524 WARHOST_WEBUI_DROP_FAIL=1 \
    sh "${ROOT}/webui/launch.sh" >"${WORKDIR}/launch-out.txt" 2>"${WORKDIR}/launch-err.txt"
  grep -qx 'WebUI listening on port 39524.' "${WORKDIR}/launch-out.txt" || fail "launch did not say it was listening"
  grep -q 'stayed root' "${WORKDIR}/launch-err.txt" || fail "launch did not warn on the container log"
  ROOT_PAGE_PID=$(sudo cat "${launch_settings}/.warhost-webui.pid")
  sudo kill -- "-$ROOT_PAGE_PID" 2>/dev/null || sudo kill "$ROOT_PAGE_PID" 2>/dev/null || true
  ROOT_PAGE_PID=
  printf 'ok lobby page keeps listening when the privilege drop fails\n'
else
  printf 'ok lobby page root drop skipped\n'
fi
