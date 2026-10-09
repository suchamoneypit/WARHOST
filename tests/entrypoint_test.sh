#!/bin/sh
# Exercises the settings entrypoint without starting the real WARNO server.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ENTRY="${ROOT}/entrypoint-unraid.sh"
WORKDIR=$(mktemp -d)
EMPTY_PORT_TABLE="${WORKDIR}/empty-ports"
mkdir -p "$EMPTY_PORT_TABLE"
holder=
trap 'if [ -n "${holder:-}" ]; then kill "$holder" 2>/dev/null || true; wait "$holder" 2>/dev/null || true; fi; rm -rf "$WORKDIR"' EXIT

SERVER_COUNT=0

ENTRY_ARGS=

make_server() {
  SERVER_COUNT=$((SERVER_COUNT + 1))
  server="${WORKDIR}/server-${SERVER_COUNT}"
  mkdir -p "$server"
  cat > "${server}/entrypoint2.sh" << 'EOF'
#!/bin/sh
set -eu
cd settings
printf 'reached-upstream\n'
printf 'args:%s\n' "$*"
EOF
  chmod 755 "${server}/entrypoint2.sh"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  if [ -f "${WORKDIR}/stdout.txt" ]; then
    printf '%s\n' '--- stdout ---' >&2
    cat "${WORKDIR}/stdout.txt" >&2
  fi
  if [ -f "${WORKDIR}/stderr.txt" ]; then
    printf '%s\n' '--- stderr ---' >&2
    cat "${WORKDIR}/stderr.txt" >&2
  fi
  exit 1
}

assert_secret_hidden() {
  if grep -F 'host-key-value' "${WORKDIR}/stdout.txt" "${WORKDIR}/stderr.txt" >/dev/null; then
    fail "dedicated key appeared in command output"
  fi
  if grep -F 'host-login' "${WORKDIR}/stdout.txt" "${WORKDIR}/stderr.txt" >/dev/null; then
    fail "Eugen login appeared in command output"
  fi
}

run_entry() {
  : > "${WORKDIR}/stdout.txt"
  : > "${WORKDIR}/stderr.txt"
  # ENTRY_ARGS is intentionally unquoted so a single pass-through flag can be set by a test.
  # shellcheck disable=SC2086
  # A later WARHOST_PORT_TABLE= in "$@" overrides the empty fixture.
  # shellcheck disable=SC2086
  if env -i PATH="$PATH" WARHOST_PORT_TABLE="$EMPTY_PORT_TABLE" "$@" sh "$ENTRY" $ENTRY_ARGS >"${WORKDIR}/stdout.txt" 2>"${WORKDIR}/stderr.txt"; then
    return 0
  fi
  return 1
}

expect_ok() {
  label=$1
  shift
  if ! run_entry "$@"; then
    fail "$label"
  fi
  assert_secret_hidden
  printf 'ok %s\n' "$label"
}

expect_fail() {
  label=$1
  shift
  if run_entry "$@"; then
    fail "$label was expected to fail"
  fi
  assert_secret_hidden
  printf 'ok %s\n' "$label"
}

make_server
ENTRY_ARGS=--from-unraid
expect_ok "writes settings and execs Eugen entrypoint" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2
ENTRY_ARGS=

settings="${server}/settings"
cmp -s "${settings}/login.ini" - << 'EOF' || fail "login.ini did not match"
login="host-login"
dedicated_key="host-key-value"
EOF

sed 's/RDPort_JungleLaw_2v2_CONQ/TestScenario_2v2/' "${ROOT}/samples/variables.ini.example" > "${WORKDIR}/expected-variables.ini"
cmp -s "${settings}/variables.ini" "${WORKDIR}/expected-variables.ini" || fail "variables.ini drifted from the sample"
cmp -s "${settings}/params_for_ai.json" "${ROOT}/samples/params_for_ai.json.example" || fail "params_for_ai.json drifted from the sample"
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "upstream entrypoint did not run from the settings directory"
grep -qx 'args:--from-unraid' "${WORKDIR}/stdout.txt" || fail "arguments were not passed through unchanged"
grep -q 'ModList 3811913066/15' "${WORKDIR}/stdout.txt" || fail "default log did not name the mod list"
grep -q 'Key last 4 alue' "${WORKDIR}/stdout.txt" || fail "default log did not name the key last 4"
grep -qx 'Next container on this host: Game Port 10401, its own settings folder, and a different Server Name. One login and key runs five servers. Players join by Server Name.' "${WORKDIR}/stdout.txt" || fail "default log did not name the next port"
if grep -q 'warning: Workshop Mod List contains 3811913066/0' "${WORKDIR}/stdout.txt"; then
  fail "default log warned about the old mod version"
fi
mode=$(stat -c '%a' "${settings}/login.ini")
[ "$mode" = "600" ] || fail "login.ini mode was ${mode}"

expect_fail "rejects a quoted dedicated key" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY='bad"key' \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2

grep -q 'bad"key' "${settings}/login.ini" && fail "rejected key was written" || true

expect_fail "rejects the Jungle Law display name" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP="Jungle Law"
grep -q 'scenario ID' "${WORKDIR}/stderr.txt" || fail "Jungle Law error did not mention the scenario ID"

expect_fail "rejects a placeholder map" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=YOUR_JUNGLE_LAW_SCENARIO_ID

expect_fail "rejects an empty map" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=

expect_fail "rejects a missing dedicated key" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2

expect_fail "rejects a dedicated key shorter than 4 characters" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=abc \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2

expect_fail "rejects a bad workshop mod list" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2 \
  MOD_LIST=not-an-id

expect_fail "rejects minimum players above the maximum" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2 \
  NB_MAX_PLAYER=4 \
  NB_MIN_PLAYER=5

expect_fail "rejects a combat rule other than 1 or 2" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2 \
  COMBAT_RULE=9

expect_fail "rejects port 0" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=0 \
  MAP=TestScenario_2v2

expect_fail "rejects an equals sign in the server name" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2 \
  SERVER_NAME='Bad=Name'

make_server
expect_ok "omits an empty workshop mod list" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2 \
  MOD_LIST= \
  MOD_TAG_LIST=
if grep -q '^ModList =' "${server}/settings/variables.ini"; then
  fail "empty mod list was still written"
fi
if grep -q '^ModTagList =' "${server}/settings/variables.ini"; then
  fail "empty mod tags were still written"
fi
if grep -q 'At least one mod version doesnt match' "${WORKDIR}/stdout.txt"; then
  fail "empty mod list still printed the version hint"
fi

make_server
expect_ok "warns when the Red Dragon mod list is version 0" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2 \
  MOD_LIST=3811913066/0
grep -q 'warning: Workshop Mod List contains 3811913066/0' "${WORKDIR}/stdout.txt" || fail "version 0 did not warn"
grep -qx 'ModList = 3811913066/0' "${server}/settings/variables.ini" || fail "version 0 was not written through"
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "version 0 warning stopped the server"

make_server
expect_ok "does not treat another mod's version 0 as the Red Dragon failure" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2 \
  MOD_LIST=123456/0
if grep -q 'warning: Workshop Mod List contains 3811913066/0' "${WORKDIR}/stdout.txt"; then
  fail "another mod's version 0 raised the Red Dragon warning"
fi
grep -q 'At least one mod version doesnt match' "${WORKDIR}/stdout.txt" || fail "a set mod list omitted the version hint"

make_server
mkdir -p "${server}/settings"
printf 'preserved-login\n' > "${server}/settings/login.ini"
printf 'preserved-variables\n' > "${server}/settings/variables.ini"
printf '{}\n' > "${server}/settings/params_for_ai.json"
expect_ok "keeps hand-edited files when write config is false" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  WRITE_CONFIG=false \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10401
grep -qx 'preserved-login' "${server}/settings/login.ini" || fail "hand-edited login.ini was replaced"
grep -qx 'Left existing WARNO settings in place.' "${WORKDIR}/stdout.txt" || fail "write-config false did not say it left files alone"
grep -qx 'Next container on this host: Game Port 10402, its own settings folder, and a different Server Name. One login and key runs five servers. Players join by Server Name.' "${WORKDIR}/stdout.txt" || fail "write-config false did not name the next port"

make_server
expect_fail "refuses write-config false when settings files are missing" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  WRITE_CONFIG=false \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400

make_server
expect_ok "starts once so the settings lock can be held" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2
grep -qx 'ServerName = WARHOST - Red Dragon 4v4' "${server}/settings/variables.ini" || fail "first server name was not written"
holder_log="${WORKDIR}/holder.out"
release="${WORKDIR}/release-lock"
: > "$holder_log"
: > "$release"
flock -n "${server}/settings/warhost.lock" sh -c 'echo held; while [ -f "$1" ]; do sleep 0.05; done' _ "$release" >"$holder_log" &
holder=$!
held=0
i=0
while [ "$i" -lt 50 ]; do
  if grep -q held "$holder_log"; then
    held=1
    break
  fi
  i=$((i + 1))
  sleep 0.05
done
[ "$held" -eq 1 ] || fail "test could not lock the settings folder"
expect_fail "refuses a second container on the same settings folder" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2 \
  SERVER_NAME="Second Server"
grep -q 'This settings folder is already used by a running container.' "${WORKDIR}/stderr.txt" || fail "shared folder error did not say the folder is in use"
grep -q '/mnt/user/appdata/warno/10401/settings' "${WORKDIR}/stderr.txt" || fail "shared folder error did not name the next folder"
grep -q 'Do not copy WARNO or Workshop files into it.' "${WORKDIR}/stderr.txt" || fail "shared folder error did not warn against copying the game"
if grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt"; then
  fail "a locked settings folder still started the server"
fi
grep -qx 'ServerName = WARHOST - Red Dragon 4v4' "${server}/settings/variables.ini" || fail "locked folder was overwritten"
rm -f "$release"
wait "$holder" || fail "lock holder did not exit"
expect_ok "starts again after the other container releases the settings folder" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2 \
  SERVER_NAME="After Lock"
grep -qx 'ServerName = After Lock' "${server}/settings/variables.ini" || fail "settings were not written after the lock was released"

make_server
taken="${WORKDIR}/taken-port"
mkdir -p "$taken"
printf '%s\n' \
  '  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode' \
  '   0: 00000000:0050 00000000:28A0 01 00000000:00000000 00:00000000 00000000     0        0 1 1 0000000000000000 100 0 0 10 0' \
  > "${taken}/tcp"
printf '%s\n' \
  '  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode' \
  '   0: 0100007F:28A0 00000000:0000 07 00000000:00000000 00:00000000 00000000     0        0 2 1 0000000000000000 100 0 0 10 0' \
  > "${taken}/udp"
expect_fail "refuses a game port that is already a local socket" \
  WARHOST_PORT_TABLE="$taken" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2
grep -q 'Game port 10400 is already in use.' "${WORKDIR}/stderr.txt" || fail "taken port error did not name the port"
grep -q 'Set this container'"'"'s Game Port to 10401, forward 10401 as TCP and UDP' "${WORKDIR}/stderr.txt" || fail "taken port error did not name the next port"
grep -q 'Server Name' "${WORKDIR}/stderr.txt" || fail "taken port error did not mention Server Name"
grep -q 'Players join by Server Name.' "${WORKDIR}/stderr.txt" || fail "taken port error did not say how players join"
if grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt"; then
  fail "a taken port still started the server"
fi

make_server
decoy="${WORKDIR}/decoy-port"
mkdir -p "$decoy"
printf '%s\n' \
  '  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode' \
  '   0: 00000000:0050 00000000:28A0 01 00000000:00000000 00:00000000 00000000     0        0 1 1 0000000000000000 100 0 0 10 0' \
  > "${decoy}/tcp"
expect_ok "ignores the game port when it appears only as a remote socket" \
  WARHOST_PORT_TABLE="$decoy" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2

make_server
time_wait="${WORKDIR}/time-wait-port"
mkdir -p "$time_wait"
printf '%s\n' \
  '  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode' \
  '   0: 00000000:28A0 00000000:0050 06 00000000:00000000 00:00000000 00000000     0        0 1 1 0000000000000000 100 0 0 10 0' \
  > "${time_wait}/tcp"
expect_ok "ignores a game port left in TCP TIME_WAIT" \
  WARHOST_PORT_TABLE="$time_wait" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2

make_server
listening="${WORKDIR}/listen-port"
mkdir -p "$listening"
printf '%s\n' \
  '  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode' \
  '   0: 00000000:28A0 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 1 1 0000000000000000 100 0 0 10 0' \
  > "${listening}/tcp"
expect_fail "refuses a game port that is already listening on TCP" \
  WARHOST_PORT_TABLE="$listening" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2
grep -q 'Game port 10400 is already in use.' "${WORKDIR}/stderr.txt" || fail "listening port error did not name the port"

if grep -R -n 'dedicated_key="' "${ROOT}/samples" "${ROOT}/templates" "${ROOT}/README.md" "${ROOT}/ca_profile.xml" | grep -v 'YOUR_EUGEN_DEDICATED_KEY_HERE'; then
  fail "repository contains a dedicated_key other than the placeholder"
fi

printf 'ok repository key scan\n'
