#!/bin/sh
# Write login.ini from the Unraid form, seed or refresh variables.ini, then start Eugen's entrypoint.
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

is_base_game_map() {
  # README base-game table, 102 scenario IDs. Workshop IDs that also start
  # with "_" are not in this list.
  case $1 in
    _3x3_Airport_1vs1_CONQ_DUEL|\
    _2x3_BlackForestStorm_1vs1_CONQ_DUEL|\
    _4x2_Chemical_1vs1_CONQ_DUEL|\
    _2x3_Death_Row_1vs1_CONQ_TRAINING|\
    _4x3_geisa_1vs1_CONQ_TRAINING|\
    _2x2_Hesse_1vs1_CONQ_DUEL|\
    _3x3_Kreide_1vs1_CONQ_DUEL|\
    _3x3_MountRiver_1vs1_CONQ_DUEL|\
    _3x3_MountRiver_1vs1_CONQ_TRAINING|\
    _2x3_Ohmen_1vs1_CONQ_DUEL|\
    _2x3_Two_lakes_1vs1_CONQ_DUEL|\
    _3x3_UrbanFrontlines_1vs1_CONQ_DUEL|\
    _2x3_Vertigo_1vs1_CONQ_DUEL|\
    _2x3_Albion_Military_Base_2vs2_CONQ|\
    _2x3_BlackForestStorm_2vs2_CONQ|\
    _4x2_Chemical_2vs2_CONQ_TRAINING|\
    _2x3_Death_Row_2vs2_CONQ|\
    _2x2_Hesse_2vs2_CONQ|\
    _5x2_Loop_2vs2_CONQ|\
    _3x3_MountRiver_2vs2_CONQ_ASSAULT|\
    _2x3_Ripple_2vs2_CONQ|\
    _2x2_Tension_2vs2_CONQ|\
    _2x2_Teufelsmoor_2vs2_CONQ|\
    _2x3_Two_lakes_2vs2_CONQ|\
    _2x3_TwoWays_2vs2_CONQ|\
    _3x3_UrbanFrontlines_2vs2_CONQ|\
    _2x3_Vertigo_2vs2_CONQ|\
    _2x3_Death_Row_2vs2_DEST|\
    _2x3_Ripple_2vs2_DEST|\
    _2x3_Two_lakes_2vs2_DEST|\
    _2x3_TwoWays_2vs2_DEST|\
    _2x3_Vertigo_2vs2_DEST|\
    _3x3_Airport_3vs3_CONQ|\
    _4x3_Cliff_3vs3_CONQ|\
    _3x3_Cyrus_3vs3_CONQ|\
    _3x3_DangerHills_3vs3_CONQ|\
    _3x3_Eiche_3vs3_CONQ|\
    _3x3_Factory_3vs3_CONQ|\
    _3x3_Kreide_3vs3_CONQ|\
    _3x3_MountRiver_3vs3_CONQ|\
    _3x3_Railway_3vs3_CONQ|\
    _3x3_Rift_3vs3_CONQ|\
    _3x3_Rocks_3vs3_CONQ|\
    _3x3_Rocks_3vs3_CONQ_ASSAULT|\
    _3x3_Stoneware_3vs3_CONQ|\
    _3x3_Surrounded_3vs3_CONQ|\
    _3x3_TripleStrike_3vs3_CONQ|\
    _3x3_TwinCities_3vs3_CONQ|\
    _2x3_TwoWays_3vs3_CONQ|\
    _3x3_UrbanFrontlines_3vs3_CONQ|\
    _3x3_Valley_3vs3_CONQ|\
    _3x3_Volcano_3vs3_CONQ|\
    _3x3_Airport_3vs3_DEST|\
    _3x3_Cyrus_3vs3_DEST|\
    _3x3_DangerHills_3vs3_DEST|\
    _3x3_Eiche_3vs3_DEST|\
    _3x3_Factory_3vs3_DEST|\
    _3x3_Kreide_3vs3_DEST|\
    _3x3_MountRiver_3vs3_DEST|\
    _3x3_Railway_3vs3_DEST|\
    _3x3_Rift_3vs3_DEST|\
    _3x3_Rocks_3vs3_DEST|\
    _3x3_Stoneware_3vs3_DEST|\
    _3x3_Surrounded_3vs3_DEST|\
    _3x3_TripleStrike_3vs3_DEST|\
    _3x3_TwinCities_3vs3_DEST|\
    _3x3_UrbanFrontlines_3vs3_DEST|\
    _3x3_Valley_3vs3_DEST|\
    _3x3_Volcano_3vs3_DEST|\
    _4x2_Chemical_4vs4_CONQ|\
    _4x2_DarkStream_4vs4_CONQ|\
    _4x2_Chemical_4vs4_DEST|\
    _3x3_Airport_10vs10_CONQ|\
    _5x2_crown_10vs10_CONQ|\
    _3x3_Cyrus_10vs10_CONQ|\
    _3x3_DangerHills_10vs10_CONQ|\
    _4x2_DarkStream_10vs10_CONQ|\
    _3x3_Factory_10vs10_CONQ|\
    _4x3_geisa_10vs10_CONQ|\
    _3x3_IronWaters_10vs10_CONQ|\
    _3x3_Kreide_10vs10_CONQ|\
    _5x2_Loop_10vs10_CONQ|\
    _3x3_Railway_10vs10_CONQ|\
    _3x3_Rift_10vs10_CONQ|\
    _3x3_Rocks_10vs10_CONQ|\
    _3x3_Stoneware_10vs10_CONQ|\
    _3x3_Surrounded_10vs10_CONQ|\
    _3x3_TripleStrike_10vs10_CONQ|\
    _3x3_TwinCities_10vs10_CONQ|\
    _3x3_UrbanFrontlines_10vs10_CONQ|\
    _3x3_Valley_10vs10_CONQ|\
    _3x3_Volcano_10vs10_CONQ|\
    _3x3_Airport_10vs10_DEST|\
    _5x2_crown_10vs10_DEST|\
    _3x3_Cyrus_10vs10_DEST|\
    _3x3_DangerHills_10vs10_DEST|\
    _4x3_geisa_10vs10_DEST|\
    _3x3_IronWaters_10vs10_DEST|\
    _3x3_Kreide_10vs10_DEST|\
    _5x2_Loop_10vs10_DEST|\
    _3x3_Rocks_10vs10_DEST|\
    _3x3_Volcano_10vs10_DEST)
      return 0
      ;;
  esac
  return 1
}

# warno-server does not log a rejected join. The client compares the number
# after the slash with Version in the mod's Config.ini.
note_workshop_mod_list() {
  list=$1
  map=$2
  tags=$3
  if [ -z "$list" ]; then
    if ! is_base_game_map "$map"; then
      printf '%s\n' "warning: Workshop Mod List is empty and Map $map is not a base-game scenario. Only a base-game map runs with no workshop mod. Turn that pack on in the WebUI, or set the map to a base-game ID such as _2x2_Hesse_2vs2_CONQ. warno-server still starts."
    fi
    if [ -n "$tags" ]; then
      printf '%s\n' "note: Workshop Mod Tags is $tags and Workshop Mod List is empty. The tags are written. They label the server in the browser and do not select modded content."
    fi
    return 0
  fi
  printf '%s\n' "Clients compare each Workshop id/version with Version in that mod's Config.ini. The client message \"At least one mod version doesnt match\" does not appear in this log."
  case $map in
    RDPort_*) ;;
    *)
      case "-$list-" in
        *-3811913066/*|*-3811913066-*)
          printf '%s\n' "warning: Map $map is not a Red Dragon scenario, and Workshop Mod List contains the Red Dragon map pack 3811913066. Players without that mod cannot join. Turn that mod off in the WebUI. warno-server still starts with the mod listed."
          return 0
          ;;
      esac
      ;;
  esac
  rest=$list
  while [ -n "$rest" ]; do
    pair=${rest%%-*}
    case $pair in
      3811913066/0|3811913066/15)
        printf '%s\n' "warning: Workshop Mod List contains ${pair}. That value fails for the Red Dragon pack. Config.ini Version was 27 on 2026-10-10. Save that mod again in the WebUI so the next start reads the current Version. warno-server still starts and logs nothing about the rejected join."
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

# Private staging names are exactly this prefix plus a unique suffix.
# SIGKILL, a host crash, and power loss skip the traps below. That leftover
# is accepted until the next start that holds warhost.lock.
stage_dir=
settings_locked=0

discard_stage_dir() {
  dir=${stage_dir:-}
  stage_dir=
  if [ -z "$dir" ]; then
    return 0
  fi
  case "$dir" in
    "${SETTINGS_DIR}/.warhost-stage."*) ;;
    *) return 0 ;;
  esac
  if [ -L "$dir" ] || [ ! -d "$dir" ]; then
    return 0
  fi
  rm -rf "$dir"
}

on_stage_exit() {
  discard_stage_dir
}

on_stage_signal() {
  discard_stage_dir
  exit 1
}

sweep_stale_staging() {
  if [ "$settings_locked" -ne 1 ]; then
    return 0
  fi
  stale=
  for stale in "${SETTINGS_DIR}/.warhost-stage."*; do
    case "$stale" in
      "${SETTINGS_DIR}/.warhost-stage."*) ;;
      *) continue ;;
    esac
    if [ -L "$stale" ] || [ ! -d "$stale" ]; then
      continue
    fi
    rm -rf "$stale"
  done
}

# A symlink at the final name is removed, not followed. mv would otherwise
# place the file inside a directory that the symlink points at.
publish_staged_file() {
  src=$1
  dest=$2
  if [ -L "$dest" ]; then
    rm -f "$dest" || die "Could not replace ${dest}."
  fi
  if [ -d "$dest" ]; then
    die "${dest} is a directory, so it was not replaced."
  fi
  mv "$src" "$dest" || die "Could not replace ${dest}."
}

# mktemp -d is atomic when this shell has it. The mkdir loop is the fallback.
make_private_stage_dir() {
  if command -v mktemp >/dev/null 2>&1; then
    created=$(mktemp -d "${SETTINGS_DIR}/.warhost-stage.XXXXXXXXXX" 2>/dev/null) || created=
    if [ -n "$created" ] && [ ! -L "$created" ] && [ -d "$created" ]; then
      printf '%s\n' "$created"
      return 0
    fi
    if [ -n "$created" ] && [ -L "$created" ]; then
      rm -f "$created"
    fi
  fi
  n=0
  while [ "$n" -lt 100 ]; do
    candidate="${SETTINGS_DIR}/.warhost-stage.$$.${n}"
    if mkdir "$candidate" 2>/dev/null; then
      printf '%s\n' "$candidate"
      return 0
    fi
    n=$((n + 1))
  done
  return 1
}

prepare_server_runtime() {
  mkdir -p "$SETTINGS_DIR"
  settings_locked=0
  if command -v flock >/dev/null 2>&1; then
    # fd 9 stays open across exec so the lock lasts as long as the server.
    exec 9>"${SETTINGS_DIR}/warhost.lock"
    if ! flock -n 9; then
      if [ -n "$NEXT_PORT" ]; then
        die "This settings folder is already used by a running container. This Game Port uses /mnt/user/appdata/warno/${EXPOSEDPORT}/settings. If that folder is the one in use, set Game Port to ${NEXT_PORT} and Settings Folder to /mnt/user/appdata/warno/${NEXT_PORT}/settings. Do not copy WARNO or Workshop files into it."
      fi
      die "This settings folder is already used by a running container. Give this container its own folder, for example /mnt/user/appdata/warno/${EXPOSEDPORT}/settings. Do not copy WARNO or Workshop files into it."
    fi
    settings_locked=1
  else
    printf '%s\n' "warning: flock is not available, so this start cannot tell whether another container is using this settings folder."
  fi
  sweep_stale_staging
  if local_port_taken "$EXPOSEDPORT"; then
    if [ -n "$NEXT_PORT" ]; then
      die "Game port ${EXPOSEDPORT} is already in use. Set this container's Game Port to ${NEXT_PORT}, forward ${NEXT_PORT} as TCP and UDP, and set Settings Folder to /mnt/user/appdata/warno/${NEXT_PORT}/settings. Give it a different Server Name in the WebUI. Players join by Server Name."
    fi
    die "Game port ${EXPOSEDPORT} is already in use. Pick a free Game Port, forward it as TCP and UDP, and give this container its own settings folder and a Server Name in the WebUI. Players join by Server Name."
  fi
}

note_next_container() {
  if [ -n "$NEXT_PORT" ]; then
    printf '%s\n' "Next container on this host: Game Port ${NEXT_PORT}, settings folder /mnt/user/appdata/warno/${NEXT_PORT}/settings, and a different Server Name in the WebUI. One login and key runs five servers. Players join by Server Name."
    return 0
  fi
  printf '%s\n' "Next container on this host: a free Game Port, its own settings folder, and a different Server Name in the WebUI. One login and key runs five servers. Players join by Server Name."
}

WORKSHOP_APP_ID=1611600
WORKSHOP_CACHE_FILE=warhost-workshop-versions.txt
workshop_cache_lines=
workshop_fetch_log=

# Prints Steam's time_updated for one Workshop item, or nothing when Steam
# gives no time. The response is one line of JSON; a quote inside a string
# is escaped, so only the item's own field matches.
workshop_time_updated() {
  if ! command -v wget >/dev/null 2>&1; then
    return 0
  fi
  wget -q -T 20 -t 2 -O - \
    --post-data "itemcount=1&publishedfileids%5B0%5D=$1" \
    https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/ 2>/dev/null |
    sed -n 's/.*"time_updated":[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n 1
}

# Downloads only Config.ini of one Workshop item into a private directory,
# reads Version, and removes the directory before returning. Every mod names
# that file Config.ini, so nothing from one item is left for the next.
fetch_workshop_version() {
  fetch_id=$1
  workshop_version=
  workshop_fetch_error=
  workshop_fetch_log=
  if ! command -v DepotDownloader >/dev/null 2>&1; then
    workshop_fetch_error="DepotDownloader is not installed in this image."
    return 1
  fi
  stage_dir=$(make_private_stage_dir) || stage_dir=
  if [ -z "$stage_dir" ]; then
    workshop_fetch_error="Could not create a private download directory under ${SETTINGS_DIR}."
    return 1
  fi
  trap 'on_stage_exit' EXIT
  trap 'on_stage_signal' HUP INT TERM
  printf '%s\n' Config.ini > "${stage_dir}/filelist.txt"
  set -- DepotDownloader -app "$WORKSHOP_APP_ID" -pubfile "$fetch_id" \
    -filelist "${stage_dir}/filelist.txt" -dir "${stage_dir}/item"
  if command -v timeout >/dev/null 2>&1; then
    set -- timeout 300 "$@"
  fi
  fetch_status=0
  # env -i keeps the Eugen login and key out of DepotDownloader's environment.
  (
    cd "$stage_dir" || exit 1
    exec env -i PATH="$PATH" HOME="$stage_dir" TMPDIR="$stage_dir" \
      DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 DOTNET_EnableDiagnostics=0 "$@"
  ) > "${stage_dir}/depotdownloader.log" 2>&1 || fetch_status=$?
  config="${stage_dir}/item/Config.ini"
  if [ "$fetch_status" -eq 0 ] && [ -f "$config" ] && [ ! -L "$config" ]; then
    workshop_version=$(sed -n 's/^[[:space:]]*Version[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$config" | head -n 1)
  fi
  if [ -z "$workshop_version" ]; then
    if [ "$fetch_status" -eq 124 ]; then
      workshop_fetch_error="DepotDownloader did not finish within 300 seconds."
    elif [ "$fetch_status" -ne 0 ]; then
      workshop_fetch_error="DepotDownloader exited with status ${fetch_status}."
    elif [ ! -f "$config" ]; then
      workshop_fetch_error="Steam sent no Config.ini for it."
    else
      workshop_fetch_error="Its Config.ini has no Version line."
    fi
    workshop_fetch_log=$(tail -n 5 "${stage_dir}/depotdownloader.log" 2>/dev/null || true)
  fi
  discard_stage_dir
  trap - EXIT
  trap - HUP INT TERM
  [ -n "$workshop_version" ]
}

print_workshop_fetch_log() {
  if [ -n "$workshop_fetch_log" ]; then
    printf '%s\n' "$workshop_fetch_log" | sed 's/^/DepotDownloader: /' >&2
  fi
}

remember_workshop_version() {
  workshop_cache_lines="${workshop_cache_lines}$1 $2 $3
"
}

# Sets workshop_version for one bare id. The cache holds "id time_updated
# Version" from the last start; Config.ini is fetched again only when Steam's
# time_updated differs or nothing is cached.
resolve_workshop_id() {
  ws_id=$1
  workshop_version=
  while read -r c_id c_time c_version c_extra; do
    if [ "$c_id" = "$ws_id" ]; then
      workshop_version=$c_version
    fi
  done << EOF
$workshop_cache_lines
EOF
  if [ -n "$workshop_version" ]; then
    return 0
  fi
  cached_time=
  cached_version=
  cache="${SETTINGS_DIR}/${WORKSHOP_CACHE_FILE}"
  if [ -f "$cache" ] && [ ! -L "$cache" ]; then
    while read -r c_id c_time c_version c_extra || [ -n "${c_id:-}" ]; do
      if [ "${c_id:-}" = "$ws_id" ] && is_number "${c_time:-}" && is_number "${c_version:-}"; then
        cached_time=$c_time
        cached_version=$c_version
      fi
    done < "$cache"
  fi
  steam_time=$(workshop_time_updated "$ws_id")
  if [ -n "$cached_version" ] && [ -n "$steam_time" ] && [ "$steam_time" = "$cached_time" ]; then
    workshop_version=$cached_version
    printf '%s\n' "Workshop item ${ws_id} is unchanged on Steam since the last check. Version ${workshop_version}."
    remember_workshop_version "$ws_id" "$cached_time" "$workshop_version"
    return 0
  fi
  if [ -n "$cached_version" ] && [ -z "$steam_time" ]; then
    workshop_version=$cached_version
    printf '%s\n' "warning: Steam gave no update time for Workshop item ${ws_id}, so Version ${workshop_version} from the last check is used. If the author has published since, players are refused until a later start reads the new Version."
    remember_workshop_version "$ws_id" "$cached_time" "$workshop_version"
    return 0
  fi
  if fetch_workshop_version "$ws_id"; then
    printf '%s\n' "Workshop item ${ws_id} is Version ${workshop_version}, read from its Config.ini. The rest of the item was not downloaded, and Config.ini has been deleted."
    remember_workshop_version "$ws_id" "${steam_time:-0}" "$workshop_version"
    return 0
  fi
  print_workshop_fetch_log
  if [ -n "$cached_version" ]; then
    workshop_version=$cached_version
    printf '%s\n' "warning: Could not read Config.ini for Workshop item ${ws_id}. ${workshop_fetch_error} Version ${workshop_version} from the last check is used, and the next start tries again."
    remember_workshop_version "$ws_id" "$cached_time" "$workshop_version"
    return 0
  fi
  die "Could not read Version for Workshop item ${ws_id}. ${workshop_fetch_error} No earlier Version is saved for it, so the server does not start. Check the id and the connection to Steam, then start the container again, or pin the number as ${ws_id}/<Version from that mod's Config.ini>."
}

# Rewrites MOD_LIST with every bare id as id/version. Pins stay as typed.
resolve_workshop_list() {
  ws_rest=$1
  ws_resolved=
  while [ -n "$ws_rest" ]; do
    ws_entry=${ws_rest%%-*}
    case $ws_rest in
      *-*) ws_rest=${ws_rest#*-} ;;
      *) ws_rest= ;;
    esac
    case $ws_entry in
      */*) ;;
      *)
        resolve_workshop_id "$ws_entry"
        ws_entry="${ws_entry}/${workshop_version}"
        ;;
    esac
    ws_resolved=${ws_resolved:+${ws_resolved}-}${ws_entry}
  done
  MOD_LIST=$ws_resolved
}

# Lobby fields used to live on the Docker form. A saved container can still
# pass them. They are not applied. The WebUI writes variables.ini.
note_ignored_lobby_env() {
  if [ -n "${SERVER_NAME:-}" ] || [ -n "${MAP:-}" ] || [ -n "${NB_MAX_PLAYER:-}" ] || [ -n "${NB_MIN_PLAYER:-}" ] || [ -n "${MAX_TEAM_SIZE:-}" ] || [ -n "${COMBAT_RULE:-}" ] || [ -n "${MOD_LIST:-}" ] || [ -n "${MOD_TAG_LIST:-}" ]; then
    printf '%s\n' "Lobby settings on the Docker template are ignored. Change the server in the WebUI."
  fi
}

# First "Key = value" in a regular file. ini_repeat is 1 when the key occurs again.
read_ini_key() {
  ini_file=$1
  ini_key=$2
  ini_value=
  ini_repeat=0
  ini_found=0
  ini_cr=$(printf '\r')
  while IFS= read -r ini_line || [ -n "$ini_line" ]; do
    ini_line=${ini_line%"$ini_cr"}
    case "$ini_line" in
      "${ini_key} = "*)
        if [ "$ini_found" -eq 1 ]; then
          ini_repeat=1
        fi
        ini_found=1
        ini_value=${ini_line#"${ini_key} = "}
        ;;
    esac
  done < "$ini_file"
}

mod_list_ok() {
  if [ -z "$1" ]; then
    return 0
  fi
  printf '%s\n' "$1" | grep -Eq '^[0-9]+(/[0-9]+)?(-[0-9]+(/[0-9]+)?)*$'
}

write_seed_variables() {
  cat > "$1" << 'EOF'
ServerName = WARHOST - default server name
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
}

replace_mod_list_line() {
  src=$1
  dest=$2
  new_list=$3
  replaced=0
  line_cr=$(printf '\r')
  while IFS= read -r ini_line || [ -n "$ini_line" ]; do
    bare_line=${ini_line%"$line_cr"}
    case "$bare_line" in
      "ModList = "*)
        if [ "$replaced" -eq 1 ]; then
          die "variables.ini repeats ModList."
        fi
        printf 'ModList = %s\n' "$new_list"
        replaced=1
        ;;
      *)
        printf '%s\n' "$ini_line"
        ;;
    esac
  done < "$src" > "$dest"
  if [ "$replaced" -eq 0 ]; then
    die "variables.ini lost its ModList line."
  fi
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

# WEB UI HOOK — delete this block to remove the WebUI.
web_ui=$(printf '%s' "${WEB_UI:-false}" | tr '[:upper:]' '[:lower:]')
case "$web_ui" in
  true|yes|1) web_ui=true ;;
  false|no|0|'') web_ui=false ;;
  *) die "WebUI must be true or false." ;;
esac
note_ignored_lobby_env
unset SERVER_NAME MAP NB_MAX_PLAYER NB_MIN_PLAYER MAX_TEAM_SIZE COMBAT_RULE MOD_LIST MOD_TAG_LIST

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

  prepare_server_runtime
  umask 077
  lobby_file="${SETTINGS_DIR}/variables.ini"
  lobby_kept=0
  if [ -L "$lobby_file" ] || [ ! -e "$lobby_file" ]; then
    lobby_kept=0
  elif [ -d "$lobby_file" ]; then
    die "${lobby_file} is a directory, so it was not replaced."
  elif [ -f "$lobby_file" ]; then
    lobby_kept=1
  else
    die "${lobby_file} is not a regular file, so it was not replaced."
  fi

  lobby_name="WARHOST - default server name"
  lobby_map="_2x2_Hesse_2vs2_CONQ"
  lobby_mods=
  lobby_mods_original=
  lobby_tags=
  if [ "$lobby_kept" -eq 1 ]; then
    read_ini_key "$lobby_file" "ServerName"
    lobby_name=$ini_value
    read_ini_key "$lobby_file" "Map"
    lobby_map=$ini_value
    read_ini_key "$lobby_file" "ModList"
    if [ "$ini_repeat" -eq 1 ]; then
      die "variables.ini repeats ModList."
    fi
    lobby_mods=$ini_value
    lobby_mods_original=$ini_value
    read_ini_key "$lobby_file" "ModTagList"
    lobby_tags=$ini_value
    if ! mod_list_ok "$lobby_mods"; then
      die "Workshop mod list must be empty, none, or Workshop ids such as 3811913066. Add /version only to pin a number, such as 3811913066/27. Join mods with a hyphen, such as 3811913066-3474588989."
    fi
    if [ -n "$lobby_mods" ]; then
      resolve_workshop_list "$lobby_mods"
      lobby_mods=$MOD_LIST
    fi
  fi

  stage_dir=$(make_private_stage_dir) || die "Could not create a private settings staging directory under ${SETTINGS_DIR}."
  trap 'on_stage_exit' EXIT
  trap 'on_stage_signal' HUP INT TERM
  if [ -z "$stage_dir" ] || [ -L "$stage_dir" ] || [ ! -d "$stage_dir" ]; then
    die "Could not create a private settings staging directory under ${SETTINGS_DIR}."
  fi
  case "$stage_dir" in
    "${SETTINGS_DIR}/.warhost-stage."*) ;;
    *) die "Could not create a private settings staging directory under ${SETTINGS_DIR}." ;;
  esac
  chmod 700 "$stage_dir" || die "Could not restrict the settings staging directory."

  tmp_login="${stage_dir}/login.ini"
  tmp_variables="${stage_dir}/variables.ini"
  tmp_ai="${stage_dir}/params_for_ai.json"
  printf 'login="%s"\n' "$EUGEN_LOGIN" > "$tmp_login"
  printf 'dedicated_key="%s"\n' "$EUGEN_DEDICATED_KEY" >> "$tmp_login"
  printf '%s\n' '{' '  "0": [],' '  "1": []' '}' > "$tmp_ai"
  refresh_mods=0
  if [ "$lobby_kept" -eq 0 ]; then
    write_seed_variables "$tmp_variables"
  elif [ "$lobby_mods" != "$lobby_mods_original" ]; then
    replace_mod_list_line "$lobby_file" "$tmp_variables" "$lobby_mods"
    refresh_mods=1
  fi
  if [ -n "$workshop_cache_lines" ]; then
    printf '%s' "$workshop_cache_lines" > "${stage_dir}/${WORKSHOP_CACHE_FILE}"
  fi

  # WARHOST_STAGING_HOLD is a test seam, not a form field. When it names an
  # existing file, wait until that file is gone before renaming into place.
  if [ -n "${WARHOST_STAGING_HOLD:-}" ]; then
    while [ -e "$WARHOST_STAGING_HOLD" ]; do
      sleep 0.05 || true
    done
  fi

  publish_staged_file "$tmp_login" "${SETTINGS_DIR}/login.ini"
  if [ "$lobby_kept" -eq 0 ] || [ "$refresh_mods" -eq 1 ]; then
    publish_staged_file "$tmp_variables" "${SETTINGS_DIR}/variables.ini"
  fi
  publish_staged_file "$tmp_ai" "${SETTINGS_DIR}/params_for_ai.json"
  if [ "$lobby_kept" -eq 0 ] || [ "$refresh_mods" -eq 1 ]; then
    chmod 600 "${SETTINGS_DIR}/login.ini" "${SETTINGS_DIR}/variables.ini" "${SETTINGS_DIR}/params_for_ai.json"
  else
    chmod 600 "${SETTINGS_DIR}/login.ini" "${SETTINGS_DIR}/params_for_ai.json"
  fi
  if [ -n "$workshop_cache_lines" ]; then
    cache_dest="${SETTINGS_DIR}/${WORKSHOP_CACHE_FILE}"
    if [ -d "$cache_dest" ] && [ ! -L "$cache_dest" ]; then
      printf '%s\n' "warning: ${cache_dest} is a directory, so Workshop Versions were not saved. The next start reads each Config.ini again."
    else
      publish_staged_file "${stage_dir}/${WORKSHOP_CACHE_FILE}" "$cache_dest"
    fi
  fi
  discard_stage_dir
  trap - EXIT
  trap - HUP INT TERM
  umask 022

  if [ "$lobby_kept" -eq 1 ] && [ -n "$lobby_mods" ]; then
    printf 'Kept variables.ini for %s on port %s. Map %s. ModList %s. Key last 4 %s.\n' "$lobby_name" "$EXPOSEDPORT" "$lobby_map" "$lobby_mods" "$key_tail"
  elif [ "$lobby_kept" -eq 1 ]; then
    printf 'Kept variables.ini for %s on port %s. Map %s. Key last 4 %s.\n' "$lobby_name" "$EXPOSEDPORT" "$lobby_map" "$key_tail"
  else
    printf 'Wrote WARNO settings for %s on port %s. Map %s. Key last 4 %s.\n' "$lobby_name" "$EXPOSEDPORT" "$lobby_map" "$key_tail"
  fi
  if [ -n "$lobby_map" ] || [ -n "$lobby_mods_original" ] || [ -n "$lobby_tags" ]; then
    note_workshop_mod_list "$lobby_mods_original" "$lobby_map" "$lobby_tags"
  fi
else
  if [ ! -f "${SETTINGS_DIR}/login.ini" ] || [ ! -f "${SETTINGS_DIR}/variables.ini" ] || [ ! -f "${SETTINGS_DIR}/params_for_ai.json" ]; then
    die "Write Config From Form is false, and login.ini, variables.ini, or params_for_ai.json is missing from ${SETTINGS_DIR}."
  fi
  prepare_server_runtime
  if ! chmod 600 "${SETTINGS_DIR}/login.ini"; then
    die "Could not restrict permissions on ${SETTINGS_DIR}/login.ini."
  fi
  printf 'Left existing WARNO settings in place.\n'
fi

note_next_container

# WEB UI HOOK — delete this block to remove the WebUI.
if [ "$web_ui" = true ]; then
  entry_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
  webui_launch="${entry_dir}/webui/launch.sh"
  if [ -x "$webui_launch" ]; then
    export SETTINGS_DIR
    # fd 9 is the settings lock. The page must not inherit it.
    if ! "$webui_launch" 9>&-; then
      printf '%s\n' "warning: web UI did not start. The game server will still start."
    fi
  else
    printf '%s\n' "warning: web UI launcher was not found. The game server will still start."
  fi
else
  web_port=$((EXPOSEDPORT + 1000))
  if [ "$web_port" -le 65535 ]; then
    if local_port_taken "$web_port"; then
      printf 'WebUI is off. Port %s is already in use.\n' "$web_port"
    else
      printf 'WebUI is off. Nothing is listening on port %s.\n' "$web_port"
    fi
  fi
fi

cd "$server_root"
exec "$UPSTREAM_ENTRYPOINT" "$@"
