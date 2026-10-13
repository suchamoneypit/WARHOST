# /webui

Serve this checkout's WebUI and open it beside the chat for Design Mode. Do not start the Unraid container.

1. Report `git branch --show-current`. If it is not `dev`, say so and still serve this checkout. The page is the files on disk in this working tree, including uncommitted edits. It is not the Unraid image `ghcr.io/suchamoneypit/warhost:dev`.
2. Use `/tmp/warhost-preview`. Create that directory if it is missing. Copy `samples/variables.ini.example` to `/tmp/warhost-preview/variables.ini` only when that file is missing, so a preview save survives a later restart. Do not use the Unraid settings folder. Do not read or write `login.ini`. Do not print Eugen logins or dedicated keys.
3. If TCP port 11400 is already this checkout's `webui/server.py`, leave that process running. Restart it only when `webui/server.py` or `webui/lobby.py` changed after that process started, and kill only that process. If a different process holds 11400, do not kill it; say so and stop. Otherwise start the server in the background from the repository root and leave it running (do not kill it when the command finishes):

   SETTINGS_DIR=/tmp/warhost-preview WARHOST_WEB_PORT=11400 python3 webui/server.py --serve

   `server.py` exits before binding if `SETTINGS_DIR` or `WARHOST_WEB_PORT` is missing. The process must stay up after the agent turn ends, so start it outside the sandbox with full permissions if the sandbox would kill it, and do not use a shell that exits the process.
4. Wait until `http://127.0.0.1:11400/` returns HTTP 200.
5. Open that URL in the Cursor browser (namespace `cursor-ide-browser`, tool `browser_navigate`) with `position` set to `side` so the pane sits beside the chat. Reuse the existing tab (do not set `newTab` unless there is no tab). Read the tool schema with GetDynamicTools before calling it.
6. Do not kill the server at the end. Tell the user the URL, the branch name, and that Design Mode is `Ctrl+Shift+D` in that pane. Running `/webui` again reloads the same URL. `webui/server.py` reads `index.html` from disk on every request (`Cache-Control: no-store`), so a reload shows the latest edit without an image rebuild. Restart the Python process only when `server.py` or `lobby.py` changed.
