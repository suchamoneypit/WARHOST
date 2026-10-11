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
stop_webui() {
  find "$WORKDIR" -name '.warhost-webui.pid' -type f 2>/dev/null |
    while IFS= read -r pidfile; do
      pid=$(cat "$pidfile" 2>/dev/null || true)
      if [ -n "${pid:-}" ]; then
        kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
      fi
    done
}
trap 'stop_webui; if [ -n "${stage_pid:-}" ]; then kill "$stage_pid" 2>/dev/null || true; wait "$stage_pid" 2>/dev/null || true; fi; if [ -n "${holder:-}" ]; then kill "$holder" 2>/dev/null || true; wait "$holder" 2>/dev/null || true; fi; rm -rf "$WORKDIR"' EXIT

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

python3 - "$ROOT" << 'PY' || fail "base-game map list does not match the README"
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
readme = root.joinpath("README.md").read_text()
start = readme.index("<summary>Base game (102 scenario IDs)</summary>")
end = readme.index("</details>", start)
readme_ids = re.findall(r"`(_[A-Za-z0-9_]+)`", readme[start:end])
entry = root.joinpath("entrypoint-unraid.sh").read_text()
fn = entry.split("is_base_game_map()", 1)[1].split("\n}", 1)[0]
script_ids = re.findall(r"(_[A-Za-z0-9_]+)", fn)
if len(readme_ids) != 102 or len(set(readme_ids)) != 102:
    sys.exit(f"README base-game table has {len(readme_ids)} ids, {len(set(readme_ids))} unique")
if set(readme_ids) != set(script_ids) or len(script_ids) != 102:
    missing = sorted(set(readme_ids) - set(script_ids))
    extra = sorted(set(script_ids) - set(readme_ids))
    sys.exit(f"missing {missing[:8]} extra {extra[:8]}")
PY
printf '%s\n' "ok base-game map list matches the README"

make_server
ENTRY_ARGS=--from-unraid
expect_ok "writes settings and execs Eugen entrypoint" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=_2x3_Ripple_2vs2_CONQ
ENTRY_ARGS=

settings="${server}/settings"
cmp -s "${settings}/login.ini" - << 'EOF' || fail "login.ini did not match"
login="host-login"
dedicated_key="host-key-value"
EOF

sed 's/_2x2_Hesse_2vs2_CONQ/_2x3_Ripple_2vs2_CONQ/' "${ROOT}/samples/variables.ini.example" > "${WORKDIR}/expected-variables.ini"
cmp -s "${settings}/variables.ini" "${WORKDIR}/expected-variables.ini" || fail "variables.ini drifted from the sample"
cmp -s "${settings}/params_for_ai.json" "${ROOT}/samples/params_for_ai.json.example" || fail "params_for_ai.json drifted from the sample"
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "upstream entrypoint did not run from the settings directory"
grep -qx 'args:--from-unraid' "${WORKDIR}/stdout.txt" || fail "arguments were not passed through unchanged"
grep -qx 'Wrote WARNO settings for WARHOST - Hesse 2v2 on port 10400. Map _2x3_Ripple_2vs2_CONQ. Key last 4 alue.' "${WORKDIR}/stdout.txt" || fail "default log named a mod list or the wrong server name"
grep -q 'Key last 4 alue' "${WORKDIR}/stdout.txt" || fail "default log did not name the key last 4"
if grep -qE '^(ModList|ModTagList) =' "${settings}/variables.ini"; then
  fail "default run wrote a workshop mod line"
fi
grep -qx 'Next container on this host: Game Port 10401, settings folder /mnt/user/appdata/warno/10401/settings, and a different Server Name. One login and key runs five servers. Players join by Server Name.' "${WORKDIR}/stdout.txt" || fail "default log did not name the next port"
if grep -qE 'warning: (Map|Workshop Mod List)' "${WORKDIR}/stdout.txt"; then
  fail "default log warned about the map or the mod list"
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
  MAP=_2x2_Hesse_2vs2_CONQ \
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
if grep -qE '^(warning|note):' "${WORKDIR}/stdout.txt"; then
  fail "empty mod list on a base-game map printed a warning or a note"
fi

make_server
expect_ok "treats none as an empty workshop mod list and tags" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=_2x2_Hesse_2vs2_CONQ \
  MOD_LIST=none \
  MOD_TAG_LIST=NONE
if grep -q '^ModList =' "${server}/settings/variables.ini"; then
  fail "none was written as a mod list"
fi
if grep -q '^ModTagList =' "${server}/settings/variables.ini"; then
  fail "NONE was written as mod tags"
fi
if grep -qE 'At least one mod version doesnt match|^(warning|note):' "${WORKDIR}/stdout.txt"; then
  fail "none still printed a mod hint or warning"
fi
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "none stopped the server"

make_server
expect_ok "warns when an empty workshop mod list is paired with a workshop map" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=RDPort_JungleLaw_2v2_CONQ \
  MOD_LIST= \
  MOD_TAG_LIST=
grep -q 'warning: Workshop Mod List is empty and Map RDPort_JungleLaw_2v2_CONQ is not a base-game scenario' "${WORKDIR}/stdout.txt" || fail "empty mod list on a Red Dragon map did not warn"
if grep -q '^ModList =' "${server}/settings/variables.ini"; then
  fail "empty mod list warning wrote a mod list"
fi
grep -qx 'Map = RDPort_JungleLaw_2v2_CONQ' "${server}/settings/variables.ini" || fail "empty mod list warning did not write the map"
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "empty mod list warning stopped the server"
if grep -q '^note:' "${WORKDIR}/stdout.txt"; then
  fail "empty tags printed the tags note"
fi

make_server
expect_ok "warns when an empty workshop mod list is paired with a workshop map that starts with an underscore" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=_3x3_WFulda_4v4_CONQ \
  MOD_LIST=
grep -q 'warning: Workshop Mod List is empty and Map _3x3_WFulda_4v4_CONQ is not a base-game scenario' "${WORKDIR}/stdout.txt" || fail "West Fulda with an empty mod list did not warn"
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "West Fulda warning stopped the server"

make_server
expect_ok "notes mod tags when no workshop mod is selected" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=_2x2_Hesse_2vs2_CONQ \
  MOD_LIST= \
  MOD_TAG_LIST=Maps-Scenarios
grep -q 'note: Workshop Mod Tags is Maps-Scenarios and Workshop Mod List is empty' "${WORKDIR}/stdout.txt" || fail "tags without a mod list did not print the note"
grep -qx 'ModTagList = Maps-Scenarios' "${server}/settings/variables.ini" || fail "tags without a mod list were not written"
if grep -q '^ModList =' "${server}/settings/variables.ini"; then
  fail "tags note wrote a mod list"
fi
if grep -q '^warning:' "${WORKDIR}/stdout.txt"; then
  fail "tags on a base-game map printed a warning"
fi
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "tags note stopped the server"

make_server
expect_ok "warns and notes when a workshop map has tags and no mod list" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=_2x2_Oslo_Conquest \
  MOD_LIST=none \
  MOD_TAG_LIST=Maps-Scenarios
grep -q 'warning: Workshop Mod List is empty and Map _2x2_Oslo_Conquest is not a base-game scenario' "${WORKDIR}/stdout.txt" || fail "Oslo with none did not warn"
grep -q 'note: Workshop Mod Tags is Maps-Scenarios and Workshop Mod List is empty' "${WORKDIR}/stdout.txt" || fail "Oslo with tags did not print the note"
if grep -q '^ModList =' "${server}/settings/variables.ini"; then
  fail "none on Oslo was written as a mod list"
fi
grep -qx 'ModTagList = Maps-Scenarios' "${server}/settings/variables.ini" || fail "Oslo tags were not written"
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "Oslo warning stopped the server"

make_server
expect_ok "warns when a base-game map lists the Red Dragon pack" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=_2x2_Hesse_2vs2_CONQ \
  MOD_LIST=3595948209/16-3811913066/27 \
  MOD_TAG_LIST=Maps-Scenarios
grep -q 'warning: Map _2x2_Hesse_2vs2_CONQ is not a Red Dragon scenario' "${WORKDIR}/stdout.txt" || fail "base-game map with the Red Dragon pack did not warn"
grep -qx 'ModList = 3595948209/16-3811913066/27' "${server}/settings/variables.ini" || fail "base-game map warning did not write the mod list through"
grep -qx 'ModTagList = Maps-Scenarios' "${server}/settings/variables.ini" || fail "base-game map warning did not write the tags through"
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "base-game map warning stopped the server"

make_server
expect_ok "names only the map warning for a base-game map with the previous preset" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=_2x2_Hesse_2vs2_CONQ \
  MOD_LIST=3811913066/15
grep -q 'warning: Map _2x2_Hesse_2vs2_CONQ is not a Red Dragon scenario' "${WORKDIR}/stdout.txt" || fail "base-game map with version 15 did not warn about the map"
if grep -q 'warning: Workshop Mod List contains' "${WORKDIR}/stdout.txt"; then
  fail "base-game map also told the operator to update the Red Dragon version"
fi

make_server
expect_ok "warns when the Red Dragon mod list is version 0" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=RDPort_JungleLaw_2v2_CONQ \
  MOD_LIST=3811913066/0
grep -q 'warning: Workshop Mod List contains 3811913066/0' "${WORKDIR}/stdout.txt" || fail "version 0 did not warn"
grep -qx 'ModList = 3811913066/0' "${server}/settings/variables.ini" || fail "version 0 was not written through"
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "version 0 warning stopped the server"

make_server
expect_ok "warns when the Red Dragon mod list is the previous preset" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=RDPort_JungleLaw_2v2_CONQ \
  MOD_LIST=3811913066/15
grep -q 'warning: Workshop Mod List contains 3811913066/15' "${WORKDIR}/stdout.txt" || fail "version 15 did not warn"
grep -qx 'ModList = 3811913066/15' "${server}/settings/variables.ini" || fail "version 15 was not written through"
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "version 15 warning stopped the server"

make_server
expect_ok "does not warn for a Red Dragon map with the current pack version" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=RDPort_JungleLaw_2v2_CONQ \
  MOD_LIST=3811913066/27 \
  MOD_TAG_LIST=Maps-Scenarios
if grep -qE '^(warning|note):' "${WORKDIR}/stdout.txt"; then
  fail "a Red Dragon map with 3811913066/27 printed a warning or a tags note"
fi
grep -qx 'ModList = 3811913066/27' "${server}/settings/variables.ini" || fail "Red Dragon mod list was not written"
grep -qx 'ModTagList = Maps-Scenarios' "${server}/settings/variables.ini" || fail "Red Dragon mod tags were not written"

make_server
expect_ok "does not treat another mod's version 0 as the Red Dragon failure" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2 \
  MOD_LIST=123456/0
if grep -qE 'warning: Workshop Mod List contains 3811913066/0|warning: Map' "${WORKDIR}/stdout.txt"; then
  fail "another mod's version 0 raised a Red Dragon warning"
fi
grep -q 'At least one mod version doesnt match' "${WORKDIR}/stdout.txt" || fail "a set mod list omitted the version hint"

# Fake Steam: wget answers the details call from details/<id>.json and
# DepotDownloader copies items/<id>.ini to Config.ini. Both log every call.
# As DepotDownloader 3.4.0 does, an item with no manifest exits 0 with no
# Config.ini, and no connection to Steam (the offline marker) exits 1.
FAKE_STEAM="${WORKDIR}/fake-steam"
mkdir -p "${FAKE_STEAM}/bin"
cat > "${FAKE_STEAM}/bin/wget" << 'EOF'
#!/bin/sh
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
id=
for arg in "$@"; do
  case $arg in
    *publishedfileids%5B0%5D=*) id=${arg##*=} ;;
  esac
done
printf '%s\n' "$id" >> "${root}/wget.calls"
if [ -n "$id" ] && [ -f "${root}/details/${id}.json" ]; then
  cat "${root}/details/${id}.json"
  exit 0
fi
exit 4
EOF
cat > "${FAKE_STEAM}/bin/DepotDownloader" << 'EOF'
#!/bin/sh
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
id=
dir=
list=
while [ "$#" -gt 0 ]; do
  case $1 in
    -pubfile) id=$2; shift 2 ;;
    -dir) dir=$2; shift 2 ;;
    -filelist) list=$2; shift 2 ;;
    *) shift ;;
  esac
done
printf '%s\n' "$id" >> "${root}/downloader.calls"
cp "$list" "${root}/filelist.last"
printf 'home=%s\ntmp=%s\ncwd=%s\ndir=%s\nlogin=%s\nkey=%s\n' "${HOME:-}" "${TMPDIR:-}" "$(pwd)" "$dir" "${EUGEN_LOGIN:-}" "${EUGEN_DEDICATED_KEY:-}" > "${root}/downloader.env"
settings=$(dirname "$(dirname "$dir")")
for other in "$settings"/.warhost-stage.*/item/Config.ini; do
  if [ -e "$other" ]; then
    printf '%s saw %s\n' "$id" "$other" >> "${root}/leftovers"
  fi
done
if [ -e "${root}/offline" ]; then
  printf 'Connection to Steam failed. Trying again (#10)...\nCould not connect to Steam after 10 tries\nUnable to get steam3 credentials.\nError: InitializeSteam failed\n'
  exit 1
fi
if [ -f "${root}/items/${id}.ini" ]; then
  mkdir -p "${dir}/.DepotDownloader"
  printf 'manifest\n' > "${dir}/.DepotDownloader/${id}.manifest"
  cp "${root}/items/${id}.ini" "${dir}/Config.ini"
  printf 'Total downloaded: 416 bytes (551 bytes uncompressed) from 1 depots\n'
  exit 0
fi
printf 'Unable to locate manifest ID for published file %s\nDisconnected from Steam\n' "$id"
exit 0
EOF
chmod 755 "${FAKE_STEAM}/bin/wget" "${FAKE_STEAM}/bin/DepotDownloader"

reset_fake_steam() {
  rm -rf "${FAKE_STEAM}/details" "${FAKE_STEAM}/items"
  mkdir -p "${FAKE_STEAM}/details" "${FAKE_STEAM}/items"
  rm -f "${FAKE_STEAM}/leftovers" "${FAKE_STEAM}/filelist.last" "${FAKE_STEAM}/downloader.env" "${FAKE_STEAM}/offline"
  : > "${FAKE_STEAM}/wget.calls"
  : > "${FAKE_STEAM}/downloader.calls"
}

# The description holds an escaped decoy, as a changelog quoted in JSON would.
steam_details() {
  printf '{"response":{"result":1,"resultcount":1,"publishedfiledetails":[{"publishedfileid":"%s","result":1,"consumer_app_id":1611600,"description":"Patch notes \\"time_updated\\":5","time_created":1790955484,"time_updated":%s,"visibility":0}]}}' "$1" "$2" > "${FAKE_STEAM}/details/$1.json"
}

steam_item() {
  printf '[Properties]\nName = Fixture\nID = %s ; Mod Steam ID, do not modify\nVersion = %s ; Value to increment when an update in this mod is incompatible with the current version\nDeckFormatVersion = 0 ; At least 1 for Gameplay mods\nModGenVersion = 201602 ; ModGen revision, do not modify\n' "$1" "$2" > "${FAKE_STEAM}/items/$1.ini"
}

# Windows line endings, with ModGenVersion before Version.
steam_item_crlf() {
  printf '[Properties]\r\nName = Fixture\r\nModGenVersion = 201602 ; ModGen revision, do not modify\r\nID = %s ; Mod Steam ID, do not modify\r\nVersion = %s ; Value to increment when an update in this mod is incompatible with the current version\r\n' "$1" "$2" > "${FAKE_STEAM}/items/$1.ini"
}

call_count() {
  wc -l < "${FAKE_STEAM}/$1" | tr -d ' '
}

reset_fake_steam
steam_details 3811913066 1791628993
steam_item 3811913066 27
make_server
expect_ok "reads Version from Config.ini for a bare workshop id" \
  PATH="${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=RDPort_JungleLaw_2v2_CONQ \
  MOD_LIST=3811913066 \
  MOD_TAG_LIST=Maps-Scenarios
grep -qx 'ModList = 3811913066/27' "${server}/settings/variables.ini" || fail "bare id was not written as id/version"
grep -qx 'Workshop item 3811913066 is Version 27, read from its Config.ini. The rest of the item was not downloaded, and Config.ini has been deleted.' "${WORKDIR}/stdout.txt" || fail "bare id did not report the Version it read"
grep -qx 'Wrote WARNO settings for WARHOST - Hesse 2v2 on port 10400. Map RDPort_JungleLaw_2v2_CONQ. ModList 3811913066/27. Key last 4 alue.' "${WORKDIR}/stdout.txt" || fail "log did not name the resolved mod list"
[ "$(call_count downloader.calls)" = 1 ] || fail "bare id did not download exactly once"
printf 'Config.ini\n' | cmp -s - "${FAKE_STEAM}/filelist.last" || fail "the download asked for more than Config.ini"
grep -qx '3811913066 1791628993 27' "${server}/settings/warhost-workshop-versions.txt" || fail "cache did not record id, update time, and Version"
for key in home tmp cwd; do
  grep -q "^${key}=${server}/settings/.warhost-stage\." "${FAKE_STEAM}/downloader.env" || fail "DepotDownloader ${key} was not the private download directory"
done
grep -qx 'login=' "${FAKE_STEAM}/downloader.env" || fail "DepotDownloader received the Eugen login"
grep -qx 'key=' "${FAKE_STEAM}/downloader.env" || fail "DepotDownloader received the Eugen dedicated key"
assert_no_stage_dirs "${server}/settings"
if grep -qE '^(warning|note):' "${WORKDIR}/stdout.txt"; then
  fail "a resolved Red Dragon id printed a warning or a note"
fi
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "bare id stopped the server"

expect_ok "reuses the cached Version while the Steam update time is unchanged" \
  PATH="${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=RDPort_JungleLaw_2v2_CONQ \
  MOD_LIST=3811913066
[ "$(call_count downloader.calls)" = 1 ] || fail "an unchanged item was downloaded again"
[ "$(call_count wget.calls)" = 2 ] || fail "the second start did not check the Steam update time"
grep -qx 'Workshop item 3811913066 is unchanged on Steam since the last check. Version 27.' "${WORKDIR}/stdout.txt" || fail "cache hit was not reported"
grep -qx 'ModList = 3811913066/27' "${server}/settings/variables.ini" || fail "cache hit did not write the cached Version"

steam_details 3811913066 1791700000
steam_item 3811913066 28
expect_ok "reads Config.ini again after the author publishes" \
  PATH="${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=RDPort_JungleLaw_2v2_CONQ \
  MOD_LIST=3811913066
[ "$(call_count downloader.calls)" = 2 ] || fail "a new Steam update time did not download Config.ini again"
grep -qx 'ModList = 3811913066/28' "${server}/settings/variables.ini" || fail "the new Version was not written"
grep -qx '3811913066 1791700000 28' "${server}/settings/warhost-workshop-versions.txt" || fail "cache did not record the new update"
assert_no_stage_dirs "${server}/settings"

rm -f "${FAKE_STEAM}/details/3811913066.json"
expect_ok "uses the cached Version when Steam gives no update time" \
  PATH="${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=RDPort_JungleLaw_2v2_CONQ \
  MOD_LIST=3811913066
[ "$(call_count downloader.calls)" = 2 ] || fail "a failed update check still downloaded"
grep -q '^warning: Steam gave no update time for Workshop item 3811913066, so Version 28 from the last check is used.' "${WORKDIR}/stdout.txt" || fail "failed update check did not warn"
grep -qx 'ModList = 3811913066/28' "${server}/settings/variables.ini" || fail "failed update check did not write the cached Version"
grep -qx '3811913066 1791700000 28' "${server}/settings/warhost-workshop-versions.txt" || fail "failed update check changed the cache"
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "failed update check stopped the server"

steam_details 3811913066 1791800000
rm -f "${FAKE_STEAM}/items/3811913066.ini"
expect_ok "keeps the cached Version when Config.ini cannot be read after an update" \
  PATH="${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=RDPort_JungleLaw_2v2_CONQ \
  MOD_LIST=3811913066
[ "$(call_count downloader.calls)" = 3 ] || fail "a new update time did not try the download"
grep -qx 'warning: Could not read Config.ini for Workshop item 3811913066. Steam sent no Config.ini for it. Version 28 from the last check is used, and the next start tries again.' "${WORKDIR}/stdout.txt" || fail "failed download did not warn"
grep -qx 'DepotDownloader: Unable to locate manifest ID for published file 3811913066' "${WORKDIR}/stderr.txt" || fail "failed download did not print the DepotDownloader log"
grep -qx '3811913066 1791700000 28' "${server}/settings/warhost-workshop-versions.txt" || fail "failed download recorded the new update time"
assert_no_stage_dirs "${server}/settings"
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "failed download with a cache stopped the server"

reset_fake_steam
steam_details 3474588989 1787211611
: > "${FAKE_STEAM}/offline"
make_server
expect_fail "refuses to start when a bare id has no cache and Steam cannot be reached" \
  PATH="${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=_2x2_Oslo_Conquest \
  MOD_LIST=3474588989
grep -q 'Could not read Version for Workshop item 3474588989. DepotDownloader exited with status 1. No earlier Version is saved for it, so the server does not start.' "${WORKDIR}/stderr.txt" || fail "failed first download did not say why"
grep -qx 'DepotDownloader: Could not connect to Steam after 10 tries' "${WORKDIR}/stderr.txt" || fail "failed first download did not print the DepotDownloader log"
grep -q 'pin the number as 3474588989/' "${WORKDIR}/stderr.txt" || fail "failed first download did not offer a pin"
if grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt"; then
  fail "a bare id with no Version started the server"
fi
[ ! -e "${server}/settings/variables.ini" ] || fail "a bare id with no Version wrote variables.ini"
assert_no_stage_dirs "${server}/settings"

reset_fake_steam
make_server
expect_fail "refuses to start when Steam sends no Config.ini for a bare id" \
  PATH="${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=_2x2_Hesse_2vs2_CONQ \
  MOD_LIST=3999999999
grep -q 'Could not read Version for Workshop item 3999999999. Steam sent no Config.ini for it. No earlier Version is saved for it' "${WORKDIR}/stderr.txt" || fail "an item with no Config.ini did not say why"
grep -q 'Check the id and the connection to Steam' "${WORKDIR}/stderr.txt" || fail "an item with no Config.ini did not ask to check the id"
[ ! -e "${server}/settings/variables.ini" ] || fail "an item with no Config.ini wrote variables.ini"
assert_no_stage_dirs "${server}/settings"

reset_fake_steam
steam_details 3811913066 1791628993
steam_item 3811913066 27
mkdir -p "${WORKDIR}/fake-timeout"
cat > "${WORKDIR}/fake-timeout/timeout" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" > "$(dirname "$0")/timeout.args"
exit 124
EOF
chmod 755 "${WORKDIR}/fake-timeout/timeout"
make_server
expect_fail "refuses to start when DepotDownloader runs past its time limit" \
  PATH="${WORKDIR}/fake-timeout:${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=RDPort_JungleLaw_2v2_CONQ \
  MOD_LIST=3811913066
grep -q '^300 DepotDownloader -app 1611600 -pubfile 3811913066 ' "${WORKDIR}/fake-timeout/timeout.args" || fail "DepotDownloader did not run under a 300 second limit"
grep -q 'Could not read Version for Workshop item 3811913066. DepotDownloader did not finish within 300 seconds.' "${WORKDIR}/stderr.txt" || fail "a timed-out download did not say why"
assert_no_stage_dirs "${server}/settings"

reset_fake_steam
steam_details 3811913066 1791628993
steam_details 3474588989 1787211611
steam_item 3811913066 27
steam_item_crlf 3474588989 14
make_server
expect_ok "resolves two bare ids one at a time with no Config.ini left between them" \
  PATH="${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=RDPort_JungleLaw_2v2_CONQ \
  MOD_LIST=3811913066-3474588989
grep -qx 'ModList = 3811913066/27-3474588989/14' "${server}/settings/variables.ini" || fail "two bare ids were not both resolved"
printf '3811913066\n3474588989\n' | cmp -s - "${FAKE_STEAM}/downloader.calls" || fail "the two ids were not downloaded in order"
[ ! -e "${FAKE_STEAM}/leftovers" ] || fail "a Config.ini was still present when the next item was fetched: $(cat "${FAKE_STEAM}/leftovers")"
grep -qx '3811913066 1791628993 27' "${server}/settings/warhost-workshop-versions.txt" || fail "cache lost the first id"
grep -qx '3474588989 1787211611 14' "${server}/settings/warhost-workshop-versions.txt" || fail "cache lost the second id"
assert_no_stage_dirs "${server}/settings"

reset_fake_steam
steam_details 3811913066 1791628993
steam_item 3811913066 27
make_server
expect_ok "resolves a repeated bare id once" \
  PATH="${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=RDPort_JungleLaw_2v2_CONQ \
  MOD_LIST=3811913066-3811913066
grep -qx 'ModList = 3811913066/27-3811913066/27' "${server}/settings/variables.ini" || fail "a repeated bare id was not resolved"
[ "$(call_count downloader.calls)" = 1 ] || fail "a repeated bare id was downloaded twice"
[ "$(call_count wget.calls)" = 1 ] || fail "a repeated bare id was checked on Steam twice"
[ "$(grep -c '^3811913066 ' "${server}/settings/warhost-workshop-versions.txt")" = 1 ] || fail "a repeated bare id was cached twice"

reset_fake_steam
steam_details 3811913066 1791628993
steam_item 3811913066 27
make_server
mkdir -p "${server}/settings/warhost-workshop-versions.txt"
expect_ok "starts without saving Versions when a directory holds the cache name" \
  PATH="${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=RDPort_JungleLaw_2v2_CONQ \
  MOD_LIST=3811913066
grep -qx 'ModList = 3811913066/27' "${server}/settings/variables.ini" || fail "a directory at the cache name blocked the resolved mod list"
grep -q '^warning: .*/warhost-workshop-versions.txt is a directory, so Workshop Versions were not saved\.' "${WORKDIR}/stdout.txt" || fail "a directory at the cache name did not warn"
[ -d "${server}/settings/warhost-workshop-versions.txt" ] || fail "the directory at the cache name was replaced"
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "a directory at the cache name stopped the server"
assert_no_stage_dirs "${server}/settings"

reset_fake_steam
steam_details 3811913066 1791628993
steam_item 3811913066 27
make_server
expect_ok "writes a pinned id/version as typed and resolves only the bare id" \
  PATH="${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=RDPort_JungleLaw_2v2_CONQ \
  MOD_LIST=3811913066-3474588989/14
grep -qx 'ModList = 3811913066/27-3474588989/14' "${server}/settings/variables.ini" || fail "a mixed list was not written as id/version"
printf '3811913066\n' | cmp -s - "${FAKE_STEAM}/downloader.calls" || fail "a pinned id was downloaded"
printf '3811913066\n' | cmp -s - "${FAKE_STEAM}/wget.calls" || fail "a pinned id was checked on Steam"

reset_fake_steam
make_server
expect_ok "does not contact Steam for a list of pins" \
  PATH="${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=_2x2_Oslo_Conquest \
  MOD_LIST=3474588989/14
[ "$(call_count wget.calls)" = 0 ] || fail "a pinned list called the Steam details API"
[ "$(call_count downloader.calls)" = 0 ] || fail "a pinned list ran DepotDownloader"
[ ! -e "${server}/settings/warhost-workshop-versions.txt" ] || fail "a pinned list wrote the version cache"
grep -qx 'ModList = 3474588989/14' "${server}/settings/variables.ini" || fail "a pinned list was not written as typed"

reset_fake_steam
steam_details 3811913066 1791628993
steam_item 3811913066 27
make_server
expect_ok "warns when a base-game map lists the bare Red Dragon id" \
  PATH="${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=_2x2_Hesse_2vs2_CONQ \
  MOD_LIST=3811913066
grep -q 'warning: Map _2x2_Hesse_2vs2_CONQ is not a Red Dragon scenario' "${WORKDIR}/stdout.txt" || fail "a bare Red Dragon id on a base-game map did not warn"
grep -qx 'ModList = 3811913066/27' "${server}/settings/variables.ini" || fail "the map warning did not write the resolved list"

reset_fake_steam
steam_details 3811913066 1791628993
steam_item 3811913066 15
make_server
expect_ok "does not call a Version read from Config.ini out of date" \
  PATH="${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=RDPort_JungleLaw_2v2_CONQ \
  MOD_LIST=3811913066
grep -qx 'ModList = 3811913066/15' "${server}/settings/variables.ini" || fail "Version 15 from Config.ini was not written"
if grep -q 'warning: Workshop Mod List contains' "${WORKDIR}/stdout.txt"; then
  fail "a Version read from Config.ini raised the typed-pin warning"
fi

expect_fail "rejects a workshop id with an empty version" \
  PATH="${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=RDPort_JungleLaw_2v2_CONQ \
  MOD_LIST=3811913066/
grep -q 'Workshop ids such as 3811913066' "${WORKDIR}/stderr.txt" || fail "an empty version did not explain the format"

reset_fake_steam
steam_details 3811913066 1791628993
steam_item 3811913066 27
make_server
mkdir -p "${server}/settings"
printf 'preserved-login\n' > "${server}/settings/login.ini"
printf 'ModList = 3811913066/15\n' > "${server}/settings/variables.ini"
printf '{}\n' > "${server}/settings/params_for_ai.json"
expect_ok "does not resolve a bare id when write config is false" \
  PATH="${FAKE_STEAM}/bin:${PATH}" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  WRITE_CONFIG=false \
  MOD_LIST=3811913066 \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400
[ "$(call_count wget.calls)" = 0 ] || fail "write config false called the Steam details API"
[ "$(call_count downloader.calls)" = 0 ] || fail "write config false ran DepotDownloader"
grep -qx 'ModList = 3811913066/15' "${server}/settings/variables.ini" || fail "write config false changed the hand-written mod list"

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
grep -qx 'ServerName = WARHOST - Hesse 2v2' "${server}/settings/variables.ini" || fail "first server name was not written"
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
grep -qx 'ServerName = WARHOST - Hesse 2v2' "${server}/settings/variables.ini" || fail "locked folder was overwritten"
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

make_server
expect_ok "lobby page off rewrites variables.ini" \
  WEB_UI=false \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=21400 \
  MAP=_2x2_Hesse_2vs2_CONQ
grep -qx 'Map = _2x2_Hesse_2vs2_CONQ' "${server}/settings/variables.ini" || fail "lobby page off did not write the map"
grep -qx 'Lobby page is off. Nothing is listening on port 22400.' "${WORKDIR}/stdout.txt" || fail "lobby page off did not name the closed port"
if [ -f "${server}/settings/.warhost-webui.pid" ]; then
  fail "lobby page off started a listener"
fi

make_server
web_taken="${WORKDIR}/web-taken"
mkdir -p "$web_taken"
printf '%s\n' \
  '  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode' \
  '   0: 00000000:5780 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 1 1 0000000000000000 100 0 0 10 0' \
  > "${web_taken}/tcp"
expect_ok "lobby page off names a taken page port" \
  WEB_UI=false \
  WARHOST_PORT_TABLE="$web_taken" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=21400 \
  MAP=_2x2_Hesse_2vs2_CONQ
grep -qx 'Lobby page is off. Port 22400 is already in use.' "${WORKDIR}/stdout.txt" || fail "lobby page off did not name the taken page port"

make_server
expect_ok "lobby page seeds variables.ini and starts beside the server" \
  WEB_UI=true \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=21400 \
  SERVER_NAME="WARHOST - Hesse 2v2" \
  MAP=_2x2_Hesse_2vs2_CONQ
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "lobby page seed did not reach the upstream entrypoint"
grep -qx 'Lobby page listening on port 22400.' "${WORKDIR}/stdout.txt" || fail "lobby page did not say it was listening"
grep -qx 'Map = _2x2_Hesse_2vs2_CONQ' "${server}/settings/variables.ini" || fail "lobby page seed did not write the map"
[ -f "${server}/settings/.warhost-webui.ready" ] || fail "lobby page did not become ready"
python3 - << 'PY' || fail "lobby page was not accepting on 0.0.0.0:22400"
import pathlib, urllib.request
body = urllib.request.urlopen("http://127.0.0.1:22400/", timeout=2).read()
if b"Scenic view" not in body:
    raise SystemExit("page body missing")
found = False
for line in pathlib.Path("/proc/net/tcp").read_text().splitlines()[1:]:
    parts = line.split()
    if len(parts) < 4:
        continue
    local = parts[1].upper()
    if local == "00000000:5780" and parts[3].upper() == "0A":
        found = True
if not found:
    raise SystemExit("not listening on 0.0.0.0:22400")
PY
page_pid=$(cat "${server}/settings/.warhost-webui.pid")
kill -0 "$page_pid" || fail "lobby page process was not running after the game entrypoint returned"
page_sid=$(ps -o sid= -p "$page_pid" | tr -d ' ')
test_sid=$(ps -o sid= -p $$ | tr -d ' ')
[ "$page_sid" != "$test_sid" ] || fail "lobby page stayed in the server session"
if grep -F 'host-key-value' "${server}/settings/.warhost-webui.log" >/dev/null; then
  fail "lobby page log contains the dedicated key"
fi
printf 'ServerName = from-the-page\nMap = _2x2_Hesse_2vs2_CONQ\n' > "${server}/settings/variables.ini"
printf 'login="stale"\n' > "${server}/settings/login.ini"
expect_ok "lobby page keeps variables.ini and still refreshes login.ini" \
  WEB_UI=true \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=21400 \
  SERVER_NAME="WARHOST - Hesse 2v2" \
  MAP=_2x2_Hesse_2vs2_CONQ
grep -qx 'ServerName = from-the-page' "${server}/settings/variables.ini" || fail "second start rewrote the lobby page file"
grep -qx 'login="host-login"' "${server}/settings/login.ini" || fail "lobby page start did not refresh login.ini"
grep -q 'Kept variables.ini from the lobby page' "${WORKDIR}/stdout.txt" || fail "second start did not say it kept variables.ini"
grep -q 'lobby page port 22400 is already in use' "${WORKDIR}/stdout.txt" "${WORKDIR}/stderr.txt" || fail "taken lobby port did not warn"
if grep -q 'Lobby page listening' "${WORKDIR}/stdout.txt"; then
  fail "taken lobby port still said it was listening"
fi
stop_webui

make_server
expect_ok "a failed lobby page still starts the server" \
  WEB_UI=true \
  WARHOST_WEBUI_FAIL=1 \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=21402 \
  MAP=_2x2_Hesse_2vs2_CONQ
grep -qx 'reached-upstream' "${WORKDIR}/stdout.txt" || fail "failed lobby page did not reach the upstream entrypoint"
grep -q 'web UI did not start' "${WORKDIR}/stdout.txt" || fail "failed lobby page did not warn"
if [ -f "${server}/settings/.warhost-webui.pid" ]; then
  fail "failed lobby page left a listener"
fi

make_server
mkdir -p "${server}/settings"
printf 'old\n' > "${server}/settings/variables.ini"
expect_fail "lobby page flag must be true or false" \
  WEB_UI=maybe \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=21403 \
  MAP=_2x2_Hesse_2vs2_CONQ
grep -qx 'old' "${server}/settings/variables.ini" || fail "bad lobby page flag rewrote variables.ini"

if grep -R -n 'dedicated_key="' "${ROOT}/samples" "${ROOT}/templates" "${ROOT}/README.md" "${ROOT}/ca_profile.xml" | grep -v 'YOUR_EUGEN_DEDICATED_KEY_HERE'; then
  fail "repository contains a dedicated_key other than the placeholder"
fi

printf 'ok repository key scan\n'
