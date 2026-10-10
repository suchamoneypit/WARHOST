#!/bin/sh
# Exercises the settings entrypoint without starting the real WARNO server.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ENTRY="${ROOT}/entrypoint-unraid.sh"
WORKDIR=$(mktemp -d)
EMPTY_PORT_TABLE="${WORKDIR}/empty-ports"
mkdir -p "$EMPTY_PORT_TABLE"
holder=
stage_pid=
trap 'if [ -n "${stage_pid:-}" ]; then kill "$stage_pid" 2>/dev/null || true; wait "$stage_pid" 2>/dev/null || true; fi; if [ -n "${holder:-}" ]; then kill "$holder" 2>/dev/null || true; wait "$holder" 2>/dev/null || true; fi; rm -rf "$WORKDIR"' EXIT

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

assert_no_stage_dirs() {
  root=$1
  for dir in "${root}/.warhost-stage."*; do
    if [ -L "$dir" ]; then
      continue
    fi
    if [ -e "$dir" ]; then
      fail "staging path remained: ${dir}"
    fi
  done
}

held_state() {
  if [ -z "${stage_pid:-}" ] || [ ! -r "/proc/${stage_pid}/stat" ]; then
    printf '%s' "gone"
    return 0
  fi
  rest=$(cat "/proc/${stage_pid}/stat" 2>/dev/null) || {
    printf '%s' "gone"
    return 0
  }
  rest=${rest##*) }
  printf '%s' "${rest%% *}"
}

wait_held_exit() {
  label=$1
  i=0
  while [ "$i" -lt 50 ]; do
    state=$(held_state)
    if [ "$state" = "gone" ] || [ "$state" = "Z" ]; then
      return 0
    fi
    i=$((i + 1))
    sleep 0.05
  done
  kill -KILL "$stage_pid" 2>/dev/null || true
  wait "$stage_pid" 2>/dev/null || true
  stage_pid=
  fail "$label"
}

start_held() {
  hold_file=$1
  shift
  : > "$hold_file"
  : > "${WORKDIR}/held-stdout.txt"
  : > "${WORKDIR}/held-stderr.txt"
  env -i WARHOST_PORT_TABLE="$EMPTY_PORT_TABLE" WARHOST_STAGING_HOLD="$hold_file" "$@" sh "$ENTRY" >"${WORKDIR}/held-stdout.txt" 2>"${WORKDIR}/held-stderr.txt" &
  stage_pid=$!
}

release_held() {
  rm -f "$1"
  wait_held_exit "held wrapper did not finish"
  if wait "$stage_pid"; then
    stage_pid=
    return 0
  fi
  stage_pid=
  fail "held wrapper failed"
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
grep -qx 'Next container on this host: Game Port 10401, settings folder /mnt/user/appdata/warno/10401/settings, and a different Server Name. One login and key runs five servers. Players join by Server Name.' "${WORKDIR}/stdout.txt" || fail "default log did not name the next port"
if grep -q 'warning: Workshop Mod List contains 3811913066/0' "${WORKDIR}/stdout.txt"; then
  fail "default log warned about the old mod version"
fi
mode=$(stat -c '%a' "${settings}/login.ini")
[ "$mode" = "600" ] || fail "login.ini mode was ${mode}"
assert_no_stage_dirs "$settings"
if [ -e "${settings}/.login.ini.new" ] || [ -L "${settings}/.login.ini.new" ]; then
  fail "fixed staging path .login.ini.new was used"
fi

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
grep -qx 'Next container on this host: Game Port 10402, settings folder /mnt/user/appdata/warno/10402/settings, and a different Server Name. One login and key runs five servers. Players join by Server Name.' "${WORKDIR}/stdout.txt" || fail "write-config false did not name the next port"

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
grep -q '/mnt/user/appdata/warno/10400/settings' "${WORKDIR}/stderr.txt" || fail "shared folder error did not name this port's folder"
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

make_server
mkdir -p "${server}/settings"
outside="${WORKDIR}/symlink-outside"
printf 'untouched-outside\n' > "$outside"
ln -s "$outside" "${server}/settings/.login.ini.new"
ln -s "$outside" "${server}/settings/.variables.ini.new"
ln -s "$outside" "${server}/settings/.params_for_ai.json.new"
expect_ok "does not follow a symlink at the old staging path" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2
grep -qx 'untouched-outside' "$outside" || fail "old staging symlink target changed"
if grep -F 'host-key-value' "$outside" >/dev/null; then
  fail "credentials were written through the old staging symlink"
fi
[ -L "${server}/settings/.login.ini.new" ] || fail "old login staging symlink was replaced"
grep -qx 'dedicated_key="host-key-value"' "${server}/settings/login.ini" || fail "credentials did not reach login.ini"
assert_no_stage_dirs "${server}/settings"

make_server
mkdir -p "${server}/settings"
outside_dir="${WORKDIR}/final-symlink-dir"
mkdir -p "$outside_dir"
chmod 755 "$outside_dir"
ln -s "$outside_dir" "${server}/settings/login.ini"
ln -s "$outside_dir" "${server}/settings/variables.ini"
ln -s "$outside_dir" "${server}/settings/params_for_ai.json"
expect_ok "replaces settings symlinks that point at a directory" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2
[ ! -L "${server}/settings/login.ini" ] || fail "login.ini stayed a symlink"
[ -f "${server}/settings/login.ini" ] || fail "login.ini was not a regular file"
grep -qx 'dedicated_key="host-key-value"' "${server}/settings/login.ini" || fail "credentials did not replace the login.ini symlink"
if [ -e "${outside_dir}/login.ini" ] || [ -e "${outside_dir}/variables.ini" ] || [ -e "${outside_dir}/params_for_ai.json" ]; then
  fail "credentials were written through a directory symlink"
fi
outside_mode=$(stat -c '%a' "$outside_dir")
[ "$outside_mode" = "755" ] || fail "directory symlink target mode became ${outside_mode}"
assert_no_stage_dirs "${server}/settings"

make_server
mkdir -p "${server}/settings"
file_target="${WORKDIR}/final-symlink-file"
printf 'untouched-file\n' > "$file_target"
ln -s "$file_target" "${server}/settings/login.ini"
expect_ok "replaces a settings symlink that points at a file" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2
grep -qx 'untouched-file' "$file_target" || fail "file symlink target changed"
[ ! -L "${server}/settings/login.ini" ] || fail "login.ini file symlink was not replaced"
grep -qx 'dedicated_key="host-key-value"' "${server}/settings/login.ini" || fail "credentials did not replace the file symlink"

make_server
mkdir -p "${server}/settings/login.ini"
expect_fail "refuses to publish login.ini when that path is a directory" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2
if grep -R -F 'host-key-value' "${server}/settings" >/dev/null 2>&1; then
  fail "a directory named login.ini received the dedicated key"
fi
assert_no_stage_dirs "${server}/settings"

make_server
hold="${WORKDIR}/stage-hold"
start_held "$hold" \
  PATH="$PATH" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2
staged=
i=0
while [ "$i" -lt 50 ]; do
  for dir in "${server}/settings/.warhost-stage."*; do
    if [ -f "$dir/login.ini" ]; then
      staged=$dir
      break
    fi
  done
  [ -n "$staged" ] && break
  i=$((i + 1))
  sleep 0.05
done
[ -n "$staged" ] || fail "staging directory did not appear"
[ ! -L "$staged" ] || fail "staging directory was a symlink"
stage_mode=$(stat -c '%a' "$staged")
[ "$stage_mode" = "700" ] || fail "staging directory mode was ${stage_mode}"
login_mode=$(stat -c '%a' "${staged}/login.ini")
[ "$login_mode" = "600" ] || fail "staged login.ini mode was ${login_mode}"
if [ -f "${server}/settings/login.ini" ]; then
  fail "login.ini was published while staging was held"
fi
kill -TERM "$stage_pid" 2>/dev/null || true
wait_held_exit "staging wrapper did not exit on TERM"
wait "$stage_pid" 2>/dev/null || true
stage_pid=
assert_no_stage_dirs "${server}/settings"
if [ -f "${server}/settings/login.ini" ]; then
  fail "TERM during staging still published login.ini"
fi
if grep -R -F 'host-key-value' "${server}/settings" >/dev/null 2>&1; then
  fail "TERM during staging left the dedicated key in the settings folder"
fi
if grep -F 'host-key-value' "${WORKDIR}/held-stdout.txt" "${WORKDIR}/held-stderr.txt" >/dev/null; then
  fail "TERM during staging printed the dedicated key"
fi
printf 'ok removes the staging directory on TERM\n'

make_server
mkdir -p "${server}/settings/.warhost-stage.stale"
printf 'stale-canary\n' > "${server}/settings/.warhost-stage.stale/canary"
chmod 700 "${server}/settings/.warhost-stage.stale"
outside_dir="${WORKDIR}/outside-stage"
mkdir -p "$outside_dir"
printf 'keep-me\n' > "${outside_dir}/marker"
ln -s "$outside_dir" "${server}/settings/.warhost-stage.linked"
hold="${WORKDIR}/stale-hold"
start_held "$hold" \
  PATH="$PATH" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2
stale_gone=0
i=0
while [ "$i" -lt 50 ]; do
  if [ ! -d "${server}/settings/.warhost-stage.stale" ]; then
    for dir in "${server}/settings/.warhost-stage."*; do
      if [ -f "$dir/login.ini" ] && [ "$dir" != "${server}/settings/.warhost-stage.stale" ]; then
        stale_gone=1
        break
      fi
    done
  fi
  [ "$stale_gone" -eq 1 ] && break
  i=$((i + 1))
  sleep 0.05
done
[ "$stale_gone" -eq 1 ] || fail "stale staging directory was still present when the new files were written"
if [ -f "${server}/settings/login.ini" ]; then
  fail "settings were published before the stale directory was gone"
fi
[ -L "${server}/settings/.warhost-stage.linked" ] || fail "staging sweep removed a symlink"
grep -qx 'keep-me' "${outside_dir}/marker" || fail "staging sweep followed a symlink"
release_held "$hold"
grep -qx 'dedicated_key="host-key-value"' "${server}/settings/login.ini" || fail "stale secret replaced the new login.ini"
if grep -R -F 'stale-canary' "${server}/settings" >/dev/null 2>&1; then
  fail "stale staging canary remained in the settings folder"
fi
[ -L "${server}/settings/.warhost-stage.linked" ] || fail "staging symlink disappeared after publish"
grep -qx 'keep-me' "${outside_dir}/marker" || fail "staging symlink target changed after publish"
assert_no_stage_dirs "${server}/settings"
printf 'ok removes a stale staging directory before publishing\n'

make_server
mkdir -p "${server}/settings"
printf 'preserved-login\n' > "${server}/settings/login.ini"
printf 'preserved-variables\n' > "${server}/settings/variables.ini"
printf '{}\n' > "${server}/settings/params_for_ai.json"
chmod 666 "${server}/settings/login.ini"
chmod 644 "${server}/settings/variables.ini"
chmod 644 "${server}/settings/params_for_ai.json"
expect_ok "restricts a hand-written login.ini when write config is false" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  WRITE_CONFIG=false \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10402
grep -qx 'preserved-login' "${server}/settings/login.ini" || fail "manual login.ini contents changed"
manual_mode=$(stat -c '%a' "${server}/settings/login.ini")
[ "$manual_mode" = "600" ] || fail "manual login.ini mode was ${manual_mode}"
variables_mode=$(stat -c '%a' "${server}/settings/variables.ini")
[ "$variables_mode" = "644" ] || fail "manual variables.ini mode changed to ${variables_mode}"
params_mode=$(stat -c '%a' "${server}/settings/params_for_ai.json")
[ "$params_mode" = "644" ] || fail "manual params_for_ai.json mode changed to ${params_mode}"
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "manual mode did not reach the upstream entrypoint"

mkdir -p "${WORKDIR}/fake-bin"
cat > "${WORKDIR}/fake-bin/mktemp" << 'EOF'
#!/bin/sh
exit 1
EOF
chmod 755 "${WORKDIR}/fake-bin/mktemp"
make_server
hold="${WORKDIR}/fallback-hold"
start_held "$hold" \
  PATH="${WORKDIR}/fake-bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2
fallback="${server}/settings/.warhost-stage.${stage_pid}.0"
i=0
while [ "$i" -lt 50 ]; do
  if [ -f "${fallback}/login.ini" ]; then
    break
  fi
  i=$((i + 1))
  sleep 0.05
done
[ -f "${fallback}/login.ini" ] || fail "mkdir fallback did not stage under the shell pid"
fallback_mode=$(stat -c '%a' "$fallback")
[ "$fallback_mode" = "700" ] || fail "mkdir fallback directory mode was ${fallback_mode}"
release_held "$hold"
grep -qx 'dedicated_key="host-key-value"' "${server}/settings/login.ini" || fail "mkdir fallback did not publish login.ini"
assert_no_stage_dirs "${server}/settings"
printf 'ok stages with mkdir when mktemp fails\n'

if grep -R -n 'dedicated_key="' "${ROOT}/samples" "${ROOT}/templates" "${ROOT}/README.md" "${ROOT}/ca_profile.xml" | grep -v 'YOUR_EUGEN_DEDICATED_KEY_HERE'; then
  fail "repository contains a dedicated_key other than the placeholder"
fi

printf 'ok repository key scan\n'
