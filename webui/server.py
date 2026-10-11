#!/usr/bin/env python3
"""Lobby page. It replaces variables.ini and does not signal the game server."""

import json
import os
import pwd
import socket
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import lobby

ROOT = Path(__file__).resolve().parent
CATALOG = json.loads((ROOT / "scenarios.json").read_text())
LIMIT = 65536


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
        raise SystemExit("lobby page port is missing")
    port = int(text)
    if port < 1 or port > 65535:
        raise SystemExit("lobby page port is missing")
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
    }


def apply_sock():
    return ROOT / "run" / "apply.sock"


def apply_text(text, settings):
    sock_path = apply_sock()
    if not sock_path.exists():
        lobby.publish(settings, text)
        return
    payload = json.dumps({"text": text}).encode() + b"\n"
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.settimeout(5)
    client.connect(str(sock_path))
    client.sendall(payload)
    reply = b""
    while b"\n" not in reply and len(reply) < 4000:
        chunk = client.recv(4000)
        if not chunk:
            break
        reply += chunk
    client.close()
    line = reply.decode(errors="replace").strip()
    if line != "OK":
        detail = line[4:] if line.startswith("ERR ") else "The lobby file was not replaced."
        raise lobby.LobbyError(detail)


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
            self._json(200, public_state(existing))
            return
        self._json(404, {"error": "Not found."})

    def do_POST(self):
        if self.path.split("?", 1)[0] != "/api/lobby":
            self._json(404, {"error": "Not found."})
            return
        if not same_origin(self.headers):
            self._json(403, {"error": "Open the lobby page and save from there."})
            return
        try:
            length = int(self.headers.get("Content-Length", "0") or "0")
        except ValueError:
            self._json(400, {"error": "The lobby page sent an unreadable save."})
            return
        if length < 0 or length > LIMIT:
            self._json(400, {"error": "The lobby page sent too much."})
            return
        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw.decode()) if raw else {}
        except (UnicodeError, json.JSONDecodeError):
            self._json(400, {"error": "The lobby page sent an unreadable save."})
            return
        dest = self.settings / "variables.ini"
        before = dest.read_bytes() if dest.is_file() and not dest.is_symlink() else None
        try:
            if payload.get("action") == "reset":
                text = lobby.reset_from_form(os.environ, CATALOG)
            elif payload.get("action") == "save":
                if dest.is_symlink():
                    existing = {"values": {}, "extras": []}
                else:
                    existing = lobby.read_ini(dest)
                managed, seeded, extras = lobby.validate_save(payload, existing, CATALOG)
                text = lobby.render(managed, seeded, extras)
            else:
                raise lobby.LobbyError("The lobby page sent an unreadable save.")
            apply_text(text, self.settings)
        except lobby.LobbyError as exc:
            after = dest.read_bytes() if dest.is_file() and not dest.is_symlink() else None
            if after != before:
                self._json(500, {"error": "The lobby file changed during a rejected save."})
                return
            self._json(400, {"error": str(exc)})
            return
        existing = lobby.read_ini(dest)
        self._json(200, public_state(existing))


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
        print(f"warning: lobby page port {port} is already in use. The game server will still start.", file=sys.stderr)
        raise SystemExit(1)
    # Open the ready file before the privilege drop. The dropped user cannot create it.
    ready_fd = os.open(settings / ".warhost-webui.ready", os.O_CREAT | os.O_WRONLY | os.O_TRUNC, 0o644)
    if drop:
        try:
            drop_to_web_user()
        except OSError as exc:
            print(f"warning: lobby page could not drop privileges and stayed root ({exc}).", file=sys.stderr)
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
            text = message["text"]
            if not isinstance(text, str) or "dedicated_key" in text or "login=" in text:
                raise lobby.LobbyError("The lobby file was not replaced.")
            lobby.publish(settings, text if text.endswith("\n") else text + "\n")
            variables = settings / "variables.ini"
            if variables.is_file() and not variables.is_symlink():
                os.chmod(variables, 0o644)
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
