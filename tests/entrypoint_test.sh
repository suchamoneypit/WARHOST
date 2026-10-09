#!/bin/sh
# Exercises the settings entrypoint without starting the real WARNO server.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ENTRY="${ROOT}/entrypoint-unraid.sh"
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

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
    printf '--- stdout ---\n' >&2
    cat "${WORKDIR}/stdout.txt" >&2
  fi
  if [ -f "${WORKDIR}/stderr.txt" ]; then
    printf '--- stderr ---\n' >&2
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
  if env -i PATH="$PATH" "$@" sh "$ENTRY" $ENTRY_ARGS >"${WORKDIR}/stdout.txt" 2>"${WORKDIR}/stderr.txt"; then
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
  EUGEN_KEY_LAST4=alue \
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
  EUGEN_KEY_LAST4=alue \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP="Jungle Law"
grep -q 'scenario ID' "${WORKDIR}/stderr.txt" || fail "Jungle Law error did not mention the scenario ID"

expect_fail "rejects a placeholder map" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EUGEN_KEY_LAST4=alue \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=YOUR_JUNGLE_LAW_SCENARIO_ID

expect_fail "rejects an empty map" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EUGEN_KEY_LAST4=alue \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=

expect_fail "rejects a missing dedicated key" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2

expect_fail "rejects a missing key last 4" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2

expect_fail "rejects a key last 4 that does not match" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EUGEN_KEY_LAST4=wxyz \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2
grep -q 'dedicated_key="host-key-value"' "${settings}/login.ini" || fail "mismatched key last 4 rewrote login.ini"

expect_fail "rejects a dedicated key shorter than 4 characters" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=abc \
  EUGEN_KEY_LAST4=abc \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2

expect_fail "rejects a bad workshop mod list" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EUGEN_KEY_LAST4=alue \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2 \
  MOD_LIST=not-an-id

expect_fail "rejects minimum players above the maximum" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EUGEN_KEY_LAST4=alue \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2 \
  NB_MAX_PLAYER=4 \
  NB_MIN_PLAYER=5

expect_fail "rejects a combat rule other than 1 or 2" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EUGEN_KEY_LAST4=alue \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2 \
  COMBAT_RULE=9

expect_fail "rejects port 0" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EUGEN_KEY_LAST4=alue \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=0 \
  MAP=TestScenario_2v2

expect_fail "rejects an equals sign in the server name" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EUGEN_KEY_LAST4=alue \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400 \
  MAP=TestScenario_2v2 \
  SERVER_NAME='Bad=Name'

make_server
expect_ok "omits an empty workshop mod list" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  EUGEN_LOGIN=host-login \
  EUGEN_DEDICATED_KEY=host-key-value \
  EUGEN_KEY_LAST4=alue \
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
  EUGEN_KEY_LAST4=alue \
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
  EUGEN_KEY_LAST4=alue \
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

make_server
expect_fail "refuses write-config false when settings files are missing" \
  UPSTREAM_ENTRYPOINT="${server}/entrypoint2.sh" \
  WRITE_CONFIG=false \
  EXPOSEDIP=203.0.113.10 \
  EXPOSEDPORT=10400

if grep -R -n 'dedicated_key="' "${ROOT}/samples" "${ROOT}/templates" "${ROOT}/README.md" "${ROOT}/ca_profile.xml" | grep -v 'YOUR_EUGEN_DEDICATED_KEY_HERE'; then
  fail "repository contains a dedicated_key other than the placeholder"
fi

printf 'ok repository key scan\n'
