#!/bin/sh
# Exercises the lobby page without starting warno-server.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
WORKDIR=$(mktemp -d)
PAGE_PID=
ROOT_PAGE_PID=
ROOT_RUN=
cleanup() {
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

python3 "${ROOT}/webui/make_catalog.py" --check
printf 'ok scenario catalog matches the README\n'

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
code=$(curl -s -o "${WORKDIR}/body.txt" -w '%{http_code}' \
  -H 'Origin: http://evil.example' \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"x","map":"_2x2_Hesse_2vs2_CONQ","gameType":0,"combatRule":2,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0}' \
  "${base}/api/lobby")
[ "$code" = "403" ] || fail "cross-site save returned ${code}"
[ "$(cksum "${settings}/variables.ini")" = "$checksum" ] || fail "cross-site save changed variables.ini"

code=$(curl -s -o "${WORKDIR}/body.txt" -w '%{http_code}' \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"x","map":"not-a-map","gameType":0,"combatRule":2,"initMoney":1500,"timeLimit":2400,"scoreLimit":2000,"incomeRate":3,"upkeep":0}' \
  "${base}/api/lobby")
[ "$code" = "400" ] || fail "rejected save returned ${code}"
[ "$(cksum "${settings}/variables.ini")" = "$checksum" ] || fail "rejected save changed variables.ini"
grep -qx 'InitMoney = 750' "${settings}/variables.ini" || fail "rejected save changed starting resources"

code=$(curl -s -o "${WORKDIR}/body.txt" -w '%{http_code}' \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"Saved Lobby","map":"RDPort_JungleLaw_2v2_CONQ","gameType":1,"combatRule":2,"initMoney":1500,"timeLimit":2400,"scoreLimit":4000,"incomeRate":5,"upkeep":5}' \
  "${base}/api/lobby")
[ "$code" = "200" ] || fail "save returned ${code}"
grep -qx 'ServerName = Saved Lobby' "${settings}/variables.ini" || fail "save did not write the server name"
grep -qx 'Map = RDPort_JungleLaw_2v2_CONQ' "${settings}/variables.ini" || fail "save did not write the map"
grep -qx 'ModList = 3811913066/27' "${settings}/variables.ini" || fail "save did not write the Red Dragon mod"
grep -qx 'ModTagList = Maps-Scenarios' "${settings}/variables.ini" || fail "save did not write the mod tags"
grep -qx 'GameType = 1' "${settings}/variables.ini" || fail "save did not write opposition"
grep -qx 'InitMoney = 1500' "${settings}/variables.ini" || fail "save did not write starting resources"
grep -qx 'TimeLimit = 2400' "${settings}/variables.ini" || fail "save did not write the time limit"
grep -qx 'IncomeRate = 5' "${settings}/variables.ini" || fail "save did not write income"
grep -qx 'Upkeep = 5' "${settings}/variables.ini" || fail "save did not write command and control"
grep -qx 'NbMaxPlayer = 4' "${settings}/variables.ini" || fail "save did not set the usual player count"
grep -qx 'AllowObservers = 1' "${settings}/variables.ini" || fail "save dropped a seeded setting"
grep -qx 'ServerName = WARHOST - Hesse 2v2' "${settings}/variables.ini.bak" || fail "save did not keep a backup"
grep -qx 'dedicated_key="host-key-value"' "${settings}/login.ini" || fail "save changed login.ini"

curl -fsS "${base}/" > "${WORKDIR}/page.html"
curl -fsS "${base}/api/lobby" > "${WORKDIR}/state.json"
if grep -F 'host-key-value' "${WORKDIR}/page.html" "${WORKDIR}/state.json" "${WORKDIR}/page.log" >/dev/null; then
  fail "lobby page exposed the dedicated key"
fi
grep -q 'Scenic view' "${WORKDIR}/page.html" || fail "page is missing the scenic slot"
grep -q 'Tactical zones' "${WORKDIR}/page.html" || fail "page is missing the tactical slot"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["map"]=="RDPort_JungleLaw_2v2_CONQ"' "${WORKDIR}/state.json" || fail "state did not return the saved map"

code=$(curl -s -o "${WORKDIR}/body.txt" -w '%{http_code}' \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"reset"}' \
  "${base}/api/lobby")
[ "$code" = "200" ] || fail "reset returned ${code}"
grep -qx 'ServerName = WARHOST - Hesse 2v2' "${settings}/variables.ini" || fail "reset did not restore the form name"
grep -qx 'Map = _2x2_Hesse_2vs2_CONQ' "${settings}/variables.ini" || fail "reset did not restore the form map"
grep -qx 'InitMoney = 750' "${settings}/variables.ini" || fail "reset did not restore the form starting resources"
if grep -q '^ModList =' "${settings}/variables.ini"; then
  fail "reset wrote a workshop mod for an empty form"
fi

outside="${WORKDIR}/outside.ini"
printf 'secret-target\n' > "$outside"
ln -sf "$outside" "${settings}/variables.ini"
code=$(curl -s -o "${WORKDIR}/body.txt" -w '%{http_code}' \
  -H 'X-WARHOST-Request: 1' \
  -H 'Content-Type: application/json' \
  --data '{"action":"save","serverName":"Saved Lobby","map":"_2x2_Hesse_2vs2_CONQ","gameType":0,"combatRule":2,"initMoney":500,"timeLimit":1200,"scoreLimit":1000,"incomeRate":0,"upkeep":0}' \
  "${base}/api/lobby")
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

  wait_ready() {
    ready_port=$1
    i=0
    while [ "$i" -lt 50 ]; do
      if sudo grep -qx "$ready_port" "${root_settings}/.warhost-webui.ready" 2>/dev/null; then
        return 0
      fi
      i=$((i + 1))
      sleep 0.05
    done
    return 1
  }

  sudo -n setsid env -u EUGEN_LOGIN -u EUGEN_DEDICATED_KEY \
    SETTINGS_DIR="$root_settings" \
    WARHOST_WEB_PORT=39522 \
    WARHOST_WEBUI_DROP_FAIL=1 \
    EXPOSEDPORT=38522 \
    python3 "${ROOT}/webui/server.py" --serve >"${WORKDIR}/root-drop.log" 2>&1 &
  wait_ready 39522 || fail "root lobby page did not become ready after a failed privilege drop"
  ROOT_PAGE_PID=$(sudo cat "${root_settings}/.warhost-webui.pid")
  code=$(curl -s -o "${WORKDIR}/root-body.txt" -w '%{http_code}' "http://127.0.0.1:39522/")
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

  sudo -n setsid env -u EUGEN_LOGIN -u EUGEN_DEDICATED_KEY \
    SETTINGS_DIR="$root_settings" \
    WARHOST_WEB_PORT=39523 \
    EXPOSEDPORT=38523 \
    python3 "${ROOT}/webui/server.py" --serve >"${WORKDIR}/root-user.log" 2>&1 &
  wait_ready 39523 || fail "root lobby page did not become ready"
  ROOT_PAGE_PID=$(sudo cat "${root_settings}/.warhost-webui.pid")
  code=$(curl -s -o "${WORKDIR}/root-body.txt" -w '%{http_code}' "http://127.0.0.1:39523/")
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
  grep -qx 'Lobby page listening on port 39524.' "${WORKDIR}/launch-out.txt" || fail "launch did not say it was listening"
  grep -q 'stayed root' "${WORKDIR}/launch-err.txt" || fail "launch did not warn on the container log"
  ROOT_PAGE_PID=$(sudo cat "${launch_settings}/.warhost-webui.pid")
  sudo kill -- "-$ROOT_PAGE_PID" 2>/dev/null || sudo kill "$ROOT_PAGE_PID" 2>/dev/null || true
  ROOT_PAGE_PID=
  printf 'ok lobby page keeps listening when the privilege drop fails\n'
else
  printf 'ok lobby page root drop skipped\n'
fi
