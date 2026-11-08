#!/bin/sh
# Start the WebUI and return. A failure here must not stop the game server.
# The entrypoint ignores this script's exit status.
set -u

unset EUGEN_LOGIN
unset EUGEN_DEDICATED_KEY

warn() {
  printf '%s\n' "$1" >&2
}

if [ -n "${WARHOST_WEBUI_FAIL:-}" ]; then
  warn "warning: WebUI did not start."
  exit 1
fi

if [ -z "${SETTINGS_DIR:-}" ] || [ -z "${EXPOSEDPORT:-}" ]; then
  warn "warning: WebUI did not start. Settings directory or game port is missing."
  exit 1
fi

case "$EXPOSEDPORT" in
  ''|*[!0-9]*)
    warn "warning: WebUI did not start. Game port is not a number."
    exit 1
    ;;
esac

# Keep these checks identical to web_port_problem in entrypoint-unraid.sh.
# A bad port must not bind, and must not stop the game server.
web_port=
if [ -z "${WEB_PORT:-}" ]; then
  web_port=$((EXPOSEDPORT + 1000))
  if [ "$web_port" -gt 65535 ]; then
    warn "warning: WebUI did not start. Game port plus 1000 is not a port."
    exit 0
  fi
else
  case "$WEB_PORT" in
    *[!0-9]*)
      warn "warning: WebUI did not start. WebUI Port is not a whole number."
      exit 0
      ;;
  esac
  if [ "$WEB_PORT" -lt 1 ] || [ "$WEB_PORT" -gt 65535 ]; then
    warn "warning: WebUI did not start. WebUI Port must be from 1 to 65535."
    exit 0
  fi
  if [ "$WEB_PORT" -eq "$EXPOSEDPORT" ]; then
    warn "warning: WebUI did not start. WebUI Port is the same as Game Port."
    exit 0
  fi
  web_port=$WEB_PORT
fi

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export WARHOST_WEB_PORT="$web_port"
export WARHOST_WEBUI_DIR="$here"

if ! command -v python3 >/dev/null 2>&1; then
  warn "warning: WebUI did not start. python3 is missing."
  exit 1
fi

# Prints one IPv4, or nothing. WARHOST_WEB_IP is a test seam, not a form field.
# A set seam that is not a dotted IPv4 does not fall through to the default route.
page_address() {
  python3 - << 'PY'
import os, socket

def usable(value):
    parts = value.split(".")
    if len(parts) != 4:
        return False
    for part in parts:
        if not part.isdigit():
            return False
        if len(part) > 1 and part.startswith("0"):
            return False
        if int(part) > 255:
            return False
    return True

if "WARHOST_WEB_IP" in os.environ:
    value = os.environ["WARHOST_WEB_IP"].strip()
    if usable(value):
        print(value)
    raise SystemExit(0)

addr = ""
try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("192.0.2.1", 9))
        addr = sock.getsockname()[0]
    finally:
        sock.close()
except OSError:
    addr = ""
if usable(addr):
    print(addr)
PY
}

say_listening() {
  still=$1
  addr=$(page_address)
  if [ -n "$still" ]; then
    if [ -n "$addr" ]; then
      printf 'WebUI still listening on http://%s:%s/.\n' "$addr" "$web_port"
    else
      printf 'WebUI still listening on port %s.\n' "$web_port"
    fi
  else
    if [ -n "$addr" ]; then
      printf 'WebUI listening on http://%s:%s/.\n' "$addr" "$web_port"
    else
      printf 'WebUI listening on port %s.\n' "$web_port"
    fi
  fi
  if [ "$web_port" != 11400 ]; then
    printf 'If the Docker button opens another server, set Advanced View WebUI to http://[IP]:[PORT:%s]/.\n' "$web_port"
  fi
}

pidfile="${SETTINGS_DIR}/.warhost-webui.pid"
if ! python3 "$here/server.py" --check; then
  if [ "${WARHOST_WEBUI_KEEP:-}" = 1 ] && [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    say_listening still
    exit 0
  fi
  warn "warning: WebUI port ${web_port} is already in use. The game server will still start."
  exit 0
fi

log="${SETTINGS_DIR}/.warhost-webui.log"
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
      warn "warning: WebUI could not drop privileges and stayed root."
    fi
    say_listening ""
    exit 0
  fi
  if [ -f "$pidfile" ] && ! kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    warn "warning: WebUI did not start."
    exit 1
  fi
  i=$((i + 1))
  sleep 0.05
done

warn "warning: WebUI did not start."
exit 1
