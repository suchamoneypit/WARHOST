#!/usr/bin/env python3
"""WebUI. It replaces variables.ini. Restart signals the wrapper, not this process."""

import json
import os
import pwd
import signal
import socket
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import lobby

ROOT = Path(__file__).resolve().parent
CATALOG = json.loads((ROOT / "scenarios.json").read_text())
LIMIT = 65536
PREVIEW_TYPES = {
    "overview.webp": "image/webp",
    "overview.png": "image/png",
    "preview.webp": "image/webp",
    "preview.png": "image/png",
}


def settings_dir():
    raw = os.environ.get("SETTINGS_DIR", "")
    if not raw:
        raise SystemExit("SETTINGS_DIR is missing")
    path = Path(raw)
    if path.is_symlink() or not path.is_dir():
        raise SystemExit("SETTINGS_DIR is not a directory")
    return path


def web_port():
    text = os.environ.get("WARHOST_WEB_PORT", "")
    if not text.isdigit() or str(int(text)) != text:
        raise SystemExit("WebUI port is missing")
    port = int(text)
    if port < 1 or port > 65535:
        raise SystemExit("WebUI port is missing")
    return port


def port_taken(port):
    table = os.environ.get("WARHOST_PORT_TABLE", "/proc/net")
    needle = f":{port:04X}"
    for name, listen_only in (("tcp", True), ("tcp6", True), ("udp", False), ("udp6", False)):
        path = Path(table) / name
        if not path.is_file():
            continue
        lines = path.read_text(errors="replace").splitlines()[1:]
        for line in lines:
            parts = line.split()
            if len(parts) < 4:
                continue
            local = parts[1].upper()
            if not local.endswith(needle):
                continue
            if listen_only and parts[3].upper() != "0A":
                continue
            return True
    probe = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        probe.bind(("0.0.0.0", port))
    except OSError:
        return True
    finally:
        probe.close()
    return False


def public_state(existing):
    values = existing.get("values", {})

    def num(key, default):
        text = values.get(key, default)
        if str(text).isdigit():
            return int(text)
        return int(default)

    return {
        "serverName": values.get("ServerName", ""),
        "map": values.get("Map", ""),
        "gameType": num("GameType", "0"),
        "combatRule": num("CombatRule", "2"),
        "initMoney": num("InitMoney", "750"),
        "timeLimit": num("TimeLimit", "1200"),
        "scoreLimit": num("ScoreLimit", "2000"),
        "incomeRate": num("IncomeRate", "3"),
        "upkeep": num("Upkeep", "0"),
        "players": num("NbMaxPlayer", "4"),
        "team": num("MaxTeamSize", "2"),
        "minPlayers": num("NbMinPlayer", "2"),
        "gamePort": os.environ.get("EXPOSEDPORT", ""),
        "modList": values.get("ModList", ""),
        "modTags": values.get("ModTagList", ""),
    }


def with_setup(state, values, decks):
    coop = values.get("CoopVsAI", "0")
    if coop in ("1", "2"):
        humans, ai = lobby.counts_from_values(values)
        state["setup"] = "pve"
        state["humanSide"] = int(coop)
        state["humans"] = humans
        state["ai"] = ai
    else:
        state["setup"] = "pvp"
        state["humanSide"] = 1
        state["humans"] = state["team"]
        state["ai"] = state["team"]
    state["decks"] = decks
    return state


def apply_sock():
    return ROOT / "run" / "apply.sock"


def helper_exchange(message):
    payload = json.dumps(message).encode() + b"\n"
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.settimeout(5)
    client.connect(str(apply_sock()))
    client.sendall(payload)
    reply = b""
    while b"\n" not in reply and len(reply) < 4000:
        chunk = client.recv(4000)
        if not chunk:
            break
        reply += chunk
    client.close()
    return reply.decode(errors="replace").strip()


def apply_text(text, settings, params=None):
    sock_path = apply_sock()
    message = {"text": text}
    if params is not None:
        message["params"] = params
    if not sock_path.exists():
        lobby.publish(settings, text)
        if params is not None:
            lobby.publish_params(settings, params)
        return
    line = helper_exchange(message)
    if line != "OK":
        detail = line[4:] if line.startswith("ERR ") else "The lobby file was not replaced."
        raise lobby.LobbyError(detail)


def wrapper_command(pid):
    try:
        raw = Path(f"/proc/{pid}/cmdline").read_bytes()
    except OSError:
        return False
    args = [part.decode(errors="replace") for part in raw.split(b"\x00") if part]
    for arg in args:
        if arg == "entrypoint-unraid.sh" or arg.endswith("/entrypoint-unraid.sh"):
            return True
    return False


def supervisor_pid(settings):
    path = Path(settings) / ".warhost-supervisor.pid"
    if path.is_symlink() or not path.is_file():
        return None
    text = path.read_text().strip()
    if not text.isdigit() or str(int(text)) != text:
        return None
    pid = int(text)
    if pid < 1 or not wrapper_command(pid):
        return None
    return pid


def signal_supervisor(settings):
    pid = supervisor_pid(settings)
    if pid is None:
        return False
    try:
        os.kill(pid, signal.SIGUSR1)
    except OSError:
        return False
    return True


def request_container_restart(settings):
    if apply_sock().exists():
        try:
            line = helper_exchange({"action": "restart"})
        except OSError:
            return False
        return line == "OK"
    return signal_supervisor(settings)


def previews_root():
    raw = os.environ.get("WARHOST_PREVIEWS", "")
    path = Path(raw) if raw else ROOT / "previews"
    if path.is_symlink() or not path.is_dir():
        return None
    return path


def preview_target(url_path):
    root = previews_root()
    if root is None or not url_path.startswith("/previews/"):
        return None
    rest = url_path[len("/previews/"):]
    if rest == "index.json":
        target = root / "index.json"
        content_type = "application/json"
    else:
        parts = rest.split("/")
        if len(parts) != 2:
            return None
        stem, name = parts
        if name not in PREVIEW_TYPES or not stem or stem in (".", ".."):
            return None
        if not all(char.isalnum() or char in "._-" for char in stem):
            return None
        target = root / stem / name
        content_type = PREVIEW_TYPES[name]
    if target.is_symlink() or not target.is_file():
        return None
    try:
        target.resolve().relative_to(root.resolve())
    except ValueError:
        return None
    return target, content_type


def same_origin(headers):
    if headers.get("X-WARHOST-Request") != "1":
        return False
    host = headers.get("Host", "")
    origin = headers.get("Origin")
    if origin and origin not in (f"http://{host}", f"https://{host}"):
        return False
    if headers.get("Sec-Fetch-Site") == "cross-site":
        return False
    return True


class Handler(BaseHTTPRequestHandler):
    settings = None
    server_version = "WARHOST"

    def log_message(self, fmt, *args):
        sys.stderr.write("%s\n" % (fmt % args))

    def _send(self, code, body, content_type):
        data = body if isinstance(body, bytes) else body.encode()
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(data)

    def _json(self, code, payload):
        self._send(code, json.dumps(payload), "application/json")

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/", "/index.html"):
            self._send(200, (ROOT / "index.html").read_bytes(), "text/html; charset=utf-8")
            return
        if path == "/scenarios.json":
            self._send(200, (ROOT / "scenarios.json").read_bytes(), "application/json")
            return
        if path == "/api/lobby":
            try:
                existing = lobby.read_ini(self.settings / "variables.ini")
            except lobby.LobbyError as exc:
                self._json(409, {"error": str(exc)})
                return
            decks = lobby.read_decks(self.settings / "params_for_ai.json")
            self._json(200, with_setup(public_state(existing), existing.get("values", {}), decks))
            return
        found = preview_target(path)
        if found:
            target, content_type = found
            self._send(200, target.read_bytes(), content_type)
            return
        self._json(404, {"error": "Not found."})

    def do_POST(self):
        if self.path.split("?", 1)[0] != "/api/lobby":
            self._json(404, {"error": "Not found."})
            return
        if not same_origin(self.headers):
            self._json(403, {"error": "Open the WebUI and save from there."})
            return
        try:
            length = int(self.headers.get("Content-Length", "0") or "0")
        except ValueError:
            self._json(400, {"error": "The WebUI sent an unreadable save."})
            return
        if length < 0 or length > LIMIT:
            self._json(400, {"error": "The WebUI sent too much."})
            return
        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw.decode()) if raw else {}
        except (UnicodeError, json.JSONDecodeError):
            self._json(400, {"error": "The WebUI sent an unreadable save."})
            return
        dest = self.settings / "variables.ini"
        params_path = self.settings / "params_for_ai.json"
        before = dest.read_bytes() if dest.is_file() and not dest.is_symlink() else None
        params_before = params_path.read_bytes() if params_path.is_file() and not params_path.is_symlink() else None
        restarted = None
        changed = None
        try:
            if dest.is_symlink() or not dest.is_file():
                existing = {"values": {}, "extras": []}
            else:
                existing = lobby.read_ini(dest)
            decks_on_disk = lobby.read_decks(params_path)
            action = payload.get("action")
            if action == "save":
                managed, seeded, extras, decks = lobby.validate_save(payload, existing, CATALOG)
                params_text = None if decks is None else lobby.render_decks(decks)
                apply_text(lobby.render(managed, seeded, extras), self.settings, params_text)
            elif action == "restart":
                changed, managed, seeded, extras, decks = lobby.settings_changed(
                    payload, existing, CATALOG, decks_on_disk
                )
                if changed and payload.get("confirmRestart") is not True:
                    self._json(409, {"error": lobby.CHANGED_RESTART, "confirmRestart": True})
                    return
                if not changed and payload.get("confirmUnchanged") is not True:
                    self._json(409, {"error": lobby.UNCHANGED_RESTART, "confirmUnchanged": True})
                    return
                if changed:
                    params_text = None if decks is None else lobby.render_decks(decks)
                    apply_text(lobby.render(managed, seeded, extras), self.settings, params_text)
                restarted = request_container_restart(self.settings)
            else:
                raise lobby.LobbyError("The WebUI sent an unreadable save.")
        except lobby.LobbyError as exc:
            after = dest.read_bytes() if dest.is_file() and not dest.is_symlink() else None
            params_after = params_path.read_bytes() if params_path.is_file() and not params_path.is_symlink() else None
            if after != before or params_after != params_before:
                self._json(500, {"error": "The lobby file changed during a rejected save."})
                return
            self._json(400, {"error": str(exc)})
            return
        saved = lobby.read_ini(dest)
        state = with_setup(public_state(saved), saved.get("values", {}), lobby.read_decks(params_path))
        if restarted is not None:
            state["changed"] = bool(changed)
            state["restarted"] = bool(restarted)
            if not restarted:
                state["restartError"] = (
                    "This page cannot restart the container. Restart it in Unraid to load the save."
                    if changed
                    else "This page cannot restart the container. Restart it in Unraid."
                )
        self._json(200, state)


def write_pid(settings):
    fd = os.open(settings / ".warhost-webui.pid", os.O_CREAT | os.O_WRONLY | os.O_TRUNC, 0o644)
    os.write(fd, f"{os.getpid()}\n".encode())
    os.close(fd)


def run_http(drop=False):
    port = web_port()
    settings = settings_dir()
    Handler.settings = settings
    write_pid(settings)
    try:
        httpd = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    except OSError:
        print(f"warning: WebUI port {port} is already in use. The game server will still start.", file=sys.stderr)
        raise SystemExit(1)
    # Open the ready file before the privilege drop. The dropped user cannot create it.
    ready_fd = os.open(settings / ".warhost-webui.ready", os.O_CREAT | os.O_WRONLY | os.O_TRUNC, 0o644)
    if drop:
        try:
            drop_to_web_user()
        except OSError as exc:
            print(f"warning: WebUI could not drop privileges and stayed root ({exc}).", file=sys.stderr)
            sys.stderr.flush()
    os.write(ready_fd, f"{port}\n".encode())
    os.close(ready_fd)
    httpd.serve_forever()


def run_helper():
    settings = settings_dir()
    run = ROOT / "run"
    sock_path = run / "apply.sock"
    if sock_path.exists() or sock_path.is_symlink():
        sock_path.unlink()
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(sock_path))
    group = pwd.getpwnam("warhost-web").pw_gid
    os.chown(sock_path, 0, group)
    os.chmod(sock_path, 0o660)
    server.listen(4)
    while True:
        conn, _addr = server.accept()
        data = b""
        while b"\n" not in data and len(data) < LIMIT:
            chunk = conn.recv(4096)
            if not chunk:
                break
            data += chunk
        try:
            message = json.loads(data.split(b"\n", 1)[0].decode())
            if not isinstance(message, dict):
                raise lobby.LobbyError("The lobby file was not replaced.")
            if message.get("action") == "restart":
                if signal_supervisor(settings):
                    conn.sendall(b"OK\n")
                else:
                    conn.sendall(b"ERR The dedicated server was not restarted.\n")
                conn.close()
                continue
            text = message["text"]
            if not isinstance(text, str) or "dedicated_key" in text or "login=" in text:
                raise lobby.LobbyError("The lobby file was not replaced.")
            params = message.get("params")
            if params is not None and (
                not isinstance(params, str) or "dedicated_key" in params or "login=" in params
            ):
                raise lobby.LobbyError("The lobby file was not replaced.")
            lobby.publish(settings, text if text.endswith("\n") else text + "\n")
            if params is not None:
                lobby.publish_params(settings, params if params.endswith("\n") else params + "\n")
            variables = settings / "variables.ini"
            if variables.is_file() and not variables.is_symlink():
                os.chmod(variables, 0o644)
            deck_file = settings / "params_for_ai.json"
            if params is not None and deck_file.is_file() and not deck_file.is_symlink():
                os.chmod(deck_file, 0o644)
        except (UnicodeError, json.JSONDecodeError, KeyError, TypeError, lobby.LobbyError) as exc:
            message = str(exc) if isinstance(exc, lobby.LobbyError) else "The lobby file was not replaced."
            conn.sendall(f"ERR {message}\n".encode())
        else:
            conn.sendall(b"OK\n")
        conn.close()


def drop_to_web_user():
    if os.environ.get("WARHOST_WEBUI_DROP_FAIL"):
        raise OSError("privilege drop failed")
    user = pwd.getpwnam("warhost-web")
    os.setgroups([])
    os.setgid(user.pw_gid)
    os.setuid(user.pw_uid)


def prepare_page_user(settings):
    user = pwd.getpwnam("warhost-web")
    run = ROOT / "run"
    run.mkdir(mode=0o750, exist_ok=True)
    os.chown(run, 0, user.pw_gid)
    os.chmod(run, 0o750)
    variables = settings / "variables.ini"
    if variables.is_file() and not variables.is_symlink():
        os.chmod(variables, 0o644)
    deck_file = settings / "params_for_ai.json"
    if deck_file.is_file() and not deck_file.is_symlink():
        os.chmod(deck_file, 0o644)


def serve_with_helper():
    import time

    settings = settings_dir()
    prepare_page_user(settings)
    if os.fork() == 0:
        try:
            run_helper()
        except Exception:
            raise SystemExit(1)
        raise SystemExit(0)
    sock_path = apply_sock()
    for _ in range(50):
        if sock_path.exists():
            break
        time.sleep(0.02)
    run_http(drop=True)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "--serve"
    if mode == "--check":
        raise SystemExit(1 if port_taken(web_port()) else 0)
    if mode == "--helper":
        run_helper()
        return
    if mode == "--serve":
        # The starter exits after the page is up. A hangup must not stop it.
        signal.signal(signal.SIGHUP, signal.SIG_IGN)
        if os.geteuid() == 0:
            try:
                pwd.getpwnam("warhost-web")
            except KeyError:
                run_http()
            else:
                serve_with_helper()
        else:
            run_http()
        return
    raise SystemExit(f"unknown mode {mode}")


if __name__ == "__main__":
    main()
