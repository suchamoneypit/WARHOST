#!/bin/sh
# Print the Unraid web-terminal command that downloads this container template
# onto the flash drive. Use it until Community Applications lists the template.
# stdout is only that command, so it can be pasted as-is.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

exec python3 - "$ROOT" "$@" << 'PY'
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

root = pathlib.Path(sys.argv[1])
private = False
template_arg = None

for arg in sys.argv[2:]:
    if arg == "--private":
        private = True
    elif arg in ("-h", "--help"):
        print(
            "usage: sh scripts/print_template_fetch.sh [--private] [templates/name.xml]\n"
            "\n"
            "Print the command to paste into the Unraid web terminal.\n"
            "Default saves my-<Name>.xml under dockerMan user templates.\n"
            "The Template dropdown shows that filename with a leading my- removed.\n"
            "--private saves the repository filename where the Apps tab lists private templates."
        )
        sys.exit(0)
    elif arg.startswith("-"):
        print(f"unknown option: {arg}", file=sys.stderr)
        sys.exit(2)
    elif template_arg is None:
        template_arg = arg
    else:
        print("too many arguments", file=sys.stderr)
        sys.exit(2)

if template_arg:
    path = pathlib.Path(template_arg)
    if not path.is_absolute():
        path = root / path
else:
    found = sorted((root / "templates").glob("*.xml"))
    if len(found) != 1:
        print(
            f"templates/ has {len(found)} xml files; pass the template path",
            file=sys.stderr,
        )
        sys.exit(2)
    path = found[0]

if not path.is_file():
    print(f"template not found: {path}", file=sys.stderr)
    sys.exit(1)

try:
    document = ET.parse(path)
except ET.ParseError as exc:
    print(f"{path.name}: not well-formed XML ({exc})", file=sys.stderr)
    sys.exit(1)

url = (document.getroot().findtext("TemplateURL") or "").strip()
if not url.startswith("https://") or " " in url:
    print("TemplateURL must be an https URL with no spaces", file=sys.stderr)
    sys.exit(1)

name = url.rstrip("/").rsplit("/", 1)[-1]
if name != path.name or not name.endswith(".xml"):
    print("TemplateURL must end with the template file name", file=sys.stderr)
    sys.exit(1)

# Unraid labels a user template from the flash filename, after removing a
# leading my-. getUserTemplatePath saves my-<Name>.xml and keeps that case.
container = (document.getroot().findtext("Name") or "").strip()
container = container.replace("/", "").replace("\\", "")
if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", container):
    print(
        "Name must be letters, digits, dots, underscores, and hyphens so the flash filename can keep its capitals",
        file=sys.stderr,
    )
    sys.exit(1)

if private:
    parts = url.split("/")
    # https://raw.githubusercontent.com/<owner>/<repo>/<ref>/...
    if len(parts) < 6 or parts[2] != "raw.githubusercontent.com" or not parts[3]:
        print(
            "--private needs a raw.githubusercontent.com TemplateURL",
            file=sys.stderr,
        )
        sys.exit(1)
    dest_dir = f"/boot/config/plugins/community.applications/private/{parts[3]}"
    dest_file = name
else:
    dest_dir = "/boot/config/plugins/dockerMan/templates-user"
    dest_file = f"my-{container}.xml"

print(f"mkdir -p {dest_dir}")
print(f"curl -fsSL -o {dest_dir}/{dest_file} \\")
print(f"  {url}")
PY
