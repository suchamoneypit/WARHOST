#!/bin/sh
# Write WARNO settings from Unraid form variables, then start Eugen's entrypoint.
# entrypoint2.sh owns the server arguments. This script does not copy them.
set -eu

UPSTREAM_ENTRYPOINT="${UPSTREAM_ENTRYPOINT:-/server/entrypoint2.sh}"

die() {
  printf '%s\n' "$1" >&2
  exit 1
}

has_line_break() {
  cr=$(printf '\r')
  case "$1" in
    *"$cr"*|*'
'*) return 0 ;;
  esac
  return 1
}

require_single_line() {
  if has_line_break "$2"; then
    die "$1 cannot contain a line break."
  fi
}

is_number() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
  esac
  return 0
}

require_number_between() {
  label=$1
  value=$2
  low=$3
  high=$4
  if ! is_number "$value"; then
    die "$label must be a whole number."
  fi
  if [ "$value" -lt "$low" ] || [ "$value" -gt "$high" ]; then
    die "$label must be from $low to $high."
  fi
}

# warno-server does not log a rejected join. The client compares the number
# after the slash with Version in the mod's Config.ini.
note_workshop_mod_list() {
  list=$1
  if [ -z "$list" ]; then
    return 0
  fi
  printf '%s\n' "Clients compare each Workshop id/version with Version in that mod's Config.ini. The client message \"At least one mod version doesnt match\" does not appear in this log."
  rest=$list
  while [ -n "$rest" ]; do
    pair=${rest%%-*}
    case $pair in
      3811913066/0)
        printf '%s\n' "warning: Workshop Mod List contains 3811913066/0. That value fails for the Red Dragon pack. Config.ini Version was 15 on 2026-10-09. Set Workshop Mod List to 3811913066/15, or to the Version line in Config.ini if the author has incremented it, then Apply. warno-server still starts and logs nothing about the rejected join."
        ;;
    esac
    case $rest in
      *-*) rest=${rest#*-} ;;
      *) break ;;
    esac
  done
}

# Prints "local-address state" for one /proc/net row.
socket_addr_state() {
  rest=$1
  i=0
  addr=
  state=
  while [ "$i" -lt 4 ]; do
    rest=${rest#"${rest%%[![:space:]]*}"}
    if [ -z "$rest" ]; then
      return 0
    fi
    word=${rest%%[[:space:]]*}
    rest=${rest#"$word"}
    i=$((i + 1))
    if [ "$i" -eq 2 ]; then
      addr=$word
    elif [ "$i" -eq 4 ]; then
      state=$word
    fi
  done
  printf '%s %s' "$addr" "$state"
}

# WARHOST_PORT_TABLE is a test seam, not a form field. Host networking
# shows the host sockets at /proc/net. The first line of each file is a header.
# listen_only=1 matches TCP state 0A (LISTEN). UDP has no listen state.
port_file_has_local() {
  file=$1
  hex=$2
  listen_only=$3
  first=1
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$first" -eq 1 ]; then
      first=0
      continue
    fi
    pair=$(socket_addr_state "$line")
    addr=${pair%% *}
    state=${pair#* }
    case $addr in
      *:*) ;;
      *) continue ;;
    esac
    suffix=${addr##*:}
    suffix=$(printf '%s' "$suffix" | tr '[:lower:]' '[:upper:]')
    if [ "$suffix" != "$hex" ]; then
      continue
    fi
    if [ "$listen_only" -eq 1 ]; then
      state=$(printf '%s' "$state" | tr '[:lower:]' '[:upper:]')
      if [ "$state" != "0A" ]; then
        continue
      fi
    fi
    return 0
  done < "$file"
  return 1
}

local_port_taken() {
  table=${WARHOST_PORT_TABLE:-/proc/net}
  hex=$(printf '%04X' "$1")
  name=
  for name in tcp tcp6; do
    file="${table}/${name}"
    if [ -f "$file" ] && port_file_has_local "$file" "$hex" 1; then
      return 0
    fi
  done
  for name in udp udp6; do
    file="${table}/${name}"
    if [ -f "$file" ] && port_file_has_local "$file" "$hex" 0; then
      return 0
    fi
  done
  return 1
}

prepare_server_runtime() {
  mkdir -p "$SETTINGS_DIR"
  if command -v flock >/dev/null 2>&1; then
    # fd 9 stays open across exec so the lock lasts as long as the server.
    exec 9>"${SETTINGS_DIR}/warhost.lock"
    if ! flock -n 9; then
      if [ -n "$NEXT_PORT" ]; then
        die "This settings folder is already used by a running container. Give this container its own folder, for example /mnt/user/appdata/warno/${NEXT_PORT}/settings. Do not copy WARNO or Workshop files into it."
      fi
      die "This settings folder is already used by a running container. Give this container its own folder, for example /mnt/user/appdata/warno/<port>/settings. Do not copy WARNO or Workshop files into it."
    fi
  else
    printf '%s\n' "warning: flock is not available, so this start cannot tell whether another container is using this settings folder."
  fi
  if local_port_taken "$EXPOSEDPORT"; then
    if [ -n "$NEXT_PORT" ]; then
      die "Game port ${EXPOSEDPORT} is already in use. Set this container's Game Port to ${NEXT_PORT}, forward ${NEXT_PORT} as TCP and UDP, and give it its own settings folder and Server Name. Players join by Server Name."
    fi
    die "Game port ${EXPOSEDPORT} is already in use. Pick a free Game Port, forward it as TCP and UDP, and give this container its own settings folder and Server Name. Players join by Server Name."
  fi
}

note_next_container() {
  if [ -n "$NEXT_PORT" ]; then
    printf '%s\n' "Next container on this host: Game Port ${NEXT_PORT}, its own settings folder, and a different Server Name. One login and key runs five servers. Players join by Server Name."
    return 0
  fi
  printf '%s\n' "Next container on this host: a free Game Port, its own settings folder, and a different Server Name. One login and key runs five servers. Players join by Server Name."
}

case "$UPSTREAM_ENTRYPOINT" in
  /*) ;;
  *) die "UPSTREAM_ENTRYPOINT must be an absolute path." ;;
esac

if [ ! -f "$UPSTREAM_ENTRYPOINT" ]; then
  die "Official WARNO entrypoint was not found at $UPSTREAM_ENTRYPOINT."
fi

server_root=$(CDPATH= cd -- "$(dirname "$UPSTREAM_ENTRYPOINT")" && pwd)
SETTINGS_DIR="${server_root}/settings"

: "${EXPOSEDIP:?Set Public WAN IP.}"
: "${EXPOSEDPORT:?Set the game port.}"
require_single_line "Public WAN IP" "$EXPOSEDIP"
require_single_line "Game port" "$EXPOSEDPORT"
case "$EXPOSEDIP" in
  *[[:space:]]*) die "Public WAN IP cannot contain spaces." ;;
esac
require_number_between "Game port" "$EXPOSEDPORT" 1 65535
if [ "$EXPOSEDPORT" -lt 65535 ]; then
  NEXT_PORT=$((EXPOSEDPORT + 1))
else
  NEXT_PORT=
fi

write_config=$(printf '%s' "${WRITE_CONFIG:-true}" | tr '[:upper:]' '[:lower:]')
case "$write_config" in
  true|yes|1) write_config=true ;;
  false|no|0) write_config=false ;;
  *) die "Write Config From Form must be true or false." ;;
esac

if [ "$write_config" = "true" ]; then
  : "${EUGEN_LOGIN:?Set your Eugen login.}"
  : "${EUGEN_DEDICATED_KEY:?Set your Eugen dedicated key.}"
  require_single_line "Eugen login" "$EUGEN_LOGIN"
  require_single_line "Eugen dedicated key" "$EUGEN_DEDICATED_KEY"

  backslash=$(printf '\\')
  case "$EUGEN_LOGIN" in
    *[[:space:]]*|*"$backslash"*|*'"'*)
      die "Eugen login cannot contain spaces, quotes, or backslashes."
      ;;
  esac
  case "$EUGEN_DEDICATED_KEY" in
    *[[:space:]]*|*"$backslash"*|*'"'*)
      die "Eugen dedicated key cannot contain spaces, quotes, or backslashes."
      ;;
  esac
  if [ "${#EUGEN_DEDICATED_KEY}" -lt 4 ]; then
    die "Eugen dedicated key must be at least 4 characters."
  fi
  key_tail=$(printf '%s' "$EUGEN_DEDICATED_KEY" | tail -c 4)

  if [ -z "${SERVER_NAME:-}" ]; then
    SERVER_NAME="WARHOST - Red Dragon 4v4"
  fi
  require_single_line "Server name" "$SERVER_NAME"
  case "$SERVER_NAME" in
    *"="*) die "Server name cannot contain =." ;;
  esac

  if [ -z "${NB_MAX_PLAYER+x}" ] || [ -z "$NB_MAX_PLAYER" ]; then
    NB_MAX_PLAYER=4
  fi
  if [ -z "${NB_MIN_PLAYER+x}" ] || [ -z "$NB_MIN_PLAYER" ]; then
    NB_MIN_PLAYER=2
  fi
  if [ -z "${MAX_TEAM_SIZE+x}" ] || [ -z "$MAX_TEAM_SIZE" ]; then
    MAX_TEAM_SIZE=2
  fi
  if [ -z "${COMBAT_RULE+x}" ] || [ -z "$COMBAT_RULE" ]; then
    COMBAT_RULE=2
  fi
  if [ -z "${MOD_LIST+x}" ]; then
    MOD_LIST="3811913066/15"
  fi
  if [ -z "${MOD_TAG_LIST+x}" ]; then
    MOD_TAG_LIST="Maps-Scenarios"
  fi

  require_single_line "Max players" "$NB_MAX_PLAYER"
  require_single_line "Minimum players" "$NB_MIN_PLAYER"
  require_single_line "Team size" "$MAX_TEAM_SIZE"
  require_single_line "Combat rule" "$COMBAT_RULE"
  require_single_line "Workshop mod list" "$MOD_LIST"
  require_single_line "Workshop mod tags" "$MOD_TAG_LIST"
  require_number_between "Max players" "$NB_MAX_PLAYER" 1 20
  require_number_between "Minimum players" "$NB_MIN_PLAYER" 1 "$NB_MAX_PLAYER"
  require_number_between "Team size" "$MAX_TEAM_SIZE" 1 "$NB_MAX_PLAYER"
  case "$COMBAT_RULE" in
    1|2) ;;
    *) die "Combat rule must be 1 for Destruction or 2 for Conquest." ;;
  esac

  if [ -n "$MOD_LIST" ] && ! printf '%s\n' "$MOD_LIST" | grep -Eq '^[0-9]+/[0-9]+(-[0-9]+/[0-9]+)*$'; then
    die "Workshop mod list must look like 3811913066/15. Join extra mods with a hyphen, such as 3811913066/15-123456/0."
  fi
  if [ -n "$MOD_TAG_LIST" ] && ! printf '%s\n' "$MOD_TAG_LIST" | grep -Eq '^[A-Za-z]+(-[A-Za-z]+)*$'; then
    die "Workshop mod tags must look like Maps-Scenarios."
  fi

  : "${MAP:?Set Map to a scenario ID. A base-game ID looks like _2x2_Hesse_2vs2_CONQ. Jungle Law is RDPort_JungleLaw_2v2_CONQ.}"
  require_single_line "Map" "$MAP"
  folded_map=$(printf '%s' "$MAP" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
  if [ "$folded_map" = "junglelaw" ]; then
    die "Map must be a scenario ID, not the display name Jungle Law. Jungle Law is RDPort_JungleLaw_2v2_CONQ."
  fi
  case "$MAP" in
    *[[:space:]]*|*"="*|*"\""*) die "Map cannot contain spaces, quotes, or =." ;;
  esac
  case "$MAP" in
    YOUR_*|REPLACE_WITH_*)
      die "Replace Map with a scenario ID. A base-game ID looks like _2x2_Hesse_2vs2_CONQ. Jungle Law is RDPort_JungleLaw_2v2_CONQ."
      ;;
  esac

  prepare_server_runtime
  tmp_login="${SETTINGS_DIR}/.login.ini.new"
  tmp_variables="${SETTINGS_DIR}/.variables.ini.new"
  tmp_ai="${SETTINGS_DIR}/.params_for_ai.json.new"
  cleanup() {
    rm -f "$tmp_login" "$tmp_variables" "$tmp_ai"
  }
  trap cleanup EXIT

  umask 077
  printf 'login="%s"\n' "$EUGEN_LOGIN" > "$tmp_login"
  printf 'dedicated_key="%s"\n' "$EUGEN_DEDICATED_KEY" >> "$tmp_login"

  {
    printf 'ServerName = %s\n' "$SERVER_NAME"
    printf 'NbMaxPlayer = %s\n' "$NB_MAX_PLAYER"
    printf 'NbMinPlayer = %s\n' "$NB_MIN_PLAYER"
    printf 'MaxTeamSize = %s\n' "$MAX_TEAM_SIZE"
    printf 'GameType = 0\n'
    printf 'CombatRule = %s\n' "$COMBAT_RULE"
    printf 'Map = %s\n' "$MAP"
    if [ -n "$MOD_LIST" ]; then
      printf 'ModList = %s\n' "$MOD_LIST"
    fi
    if [ -n "$MOD_TAG_LIST" ]; then
      printf 'ModTagList = %s\n' "$MOD_TAG_LIST"
    fi
    printf 'MapRotationType = 0\n'
    printf 'InitMoney = 750\n'
    printf 'TimeLimit = 1200\n'
    printf 'ScoreLimit = 2000\n'
    printf 'WarmupCountdown = 60\n'
    printf 'LoadingTimeMax = 120\n'
    printf 'DeploiementTimeMax = 120\n'
    printf 'DebriefingTimeMax = 60\n'
    printf 'DeltaMaxTeamSize = 0\n'
    printf 'IncomeRate = 3\n'
    printf 'Upkeep = 0\n'
    printf 'AllowObservers = 1\n'
    printf 'ObserverDelay = 120\n'
  } > "$tmp_variables"

  printf '%s\n' '{' '  "0": [],' '  "1": []' '}' > "$tmp_ai"

  mv "$tmp_login" "${SETTINGS_DIR}/login.ini"
  mv "$tmp_variables" "${SETTINGS_DIR}/variables.ini"
  mv "$tmp_ai" "${SETTINGS_DIR}/params_for_ai.json"
  chmod 600 "${SETTINGS_DIR}/login.ini" "${SETTINGS_DIR}/variables.ini" "${SETTINGS_DIR}/params_for_ai.json"
  trap - EXIT
  umask 022

  if [ -n "$MOD_LIST" ]; then
    printf 'Wrote WARNO settings for %s on port %s. Map %s. ModList %s. Key last 4 %s.\n' "$SERVER_NAME" "$EXPOSEDPORT" "$MAP" "$MOD_LIST" "$key_tail"
  else
    printf 'Wrote WARNO settings for %s on port %s. Map %s. Key last 4 %s.\n' "$SERVER_NAME" "$EXPOSEDPORT" "$MAP" "$key_tail"
  fi
  note_workshop_mod_list "$MOD_LIST"
else
  if [ ! -f "${SETTINGS_DIR}/login.ini" ] || [ ! -f "${SETTINGS_DIR}/variables.ini" ] || [ ! -f "${SETTINGS_DIR}/params_for_ai.json" ]; then
    die "Write Config From Form is false, and login.ini, variables.ini, or params_for_ai.json is missing from ${SETTINGS_DIR}."
  fi
  prepare_server_runtime
  printf 'Left existing WARNO settings in place.\n'
fi

note_next_container

cd "$server_root"
exec "$UPSTREAM_ENTRYPOINT" "$@"
