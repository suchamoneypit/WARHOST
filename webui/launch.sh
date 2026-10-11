#!/bin/sh
# Start the lobby page and return. A failure here must not stop the game server.
# The entrypoint ignores this script's exit status.
set -u

unset EUGEN_LOGIN
unset EUGEN_DEDICATED_KEY

warn() {
  printf '%s\n' "$1" >&2
}

if [ -n "${WARHOST_WEBUI_FAIL:-}" ]; then
  warn "warning: web UI did not start."
  exit 1
fi

if [ -z "${SETTINGS_DIR:-}" ] || [ -z "${EXPOSEDPORT:-}" ]; then
  warn "warning: web UI did not start. Settings directory or game port is missing."
  exit 1
fi

case "$EXPOSEDPORT" in
  ''|*[!0-9]*)
    warn "warning: web UI did not start. Game port is not a number."
    exit 1
    ;;
esac

web_port=$((EXPOSEDPORT + 1000))
if [ "$web_port" -gt 65535 ]; then
  warn "warning: web UI did not start. Game port plus 1000 is not a port."
  exit 1
fi

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export WARHOST_WEB_PORT="$web_port"
export WARHOST_WEBUI_DIR="$here"

if ! command -v python3 >/dev/null 2>&1; then
  warn "warning: web UI did not start. python3 is missing."
  exit 1
fi

if ! python3 "$here/server.py" --check; then
  warn "warning: lobby page port ${web_port} is already in use. The game server will still start."
  exit 0
fi

log="${SETTINGS_DIR}/.warhost-webui.log"
pidfile="${SETTINGS_DIR}/.warhost-webui.pid"
ready="${SETTINGS_DIR}/.warhost-webui.ready"
rm -f "$ready" "$pidfile"

# setsid may fork when it is already a process group leader. The server writes its own pid.
setsid env PYTHONUNBUFFERED=1 python3 "$here/server.py" --serve >>"$log" 2>&1 9>&- &

page_up() {
  python3 - >/dev/null 2>&1 << 'PY'
import os, pathlib, socket
port = int(os.environ["WARHOST_WEB_PORT"])
needle = ":%04X" % port
found = False
tcp = pathlib.Path("/proc/net/tcp")
if tcp.is_file():
    for line in tcp.read_text(errors="replace").splitlines()[1:]:
        parts = line.split()
        if len(parts) < 4:
            continue
        local = parts[1].upper()
        if local.endswith(needle) and parts[3].upper() == "0A" and local.startswith("00000000:"):
            found = True
            break
if not found:
    raise SystemExit(1)
socket.create_connection(("127.0.0.1", port), 2).close()
PY
}

i=0
while [ "$i" -lt 50 ]; do
  if [ -f "$ready" ] && grep -qx "$web_port" "$ready" && page_up; then
    if grep -q 'stayed root' "$log"; then
      warn "warning: lobby page could not drop privileges and stayed root."
    fi
    printf 'Lobby page listening on port %s.\n' "$web_port"
    exit 0
  fi
  if [ -f "$pidfile" ] && ! kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    warn "warning: web UI did not start."
    exit 1
  fi
  i=$((i + 1))
  sleep 0.05
done

warn "warning: web UI did not start."
exit 1
