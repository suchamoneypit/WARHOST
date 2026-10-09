#!/bin/sh
# XML well-formedness and local repository checks.
# A successful run shows these files parse and match the checks below.
# It does not show that Unraid accepts or runs the template.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

python3 - "$ROOT" << 'PY'
import pathlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

root = pathlib.Path(sys.argv[1])
errors = []


def fail(message):
    errors.append(message)


def parse_xml(relative):
    path = root / relative
    try:
        tree = ET.parse(path)
    except ET.ParseError as exc:
        fail(f"{relative}: not well-formed XML ({exc})")
        return None
    print(f"well-formed {relative}")
    return tree.getroot()


template = parse_xml("templates/warhost.xml")
profile = parse_xml("ca_profile.xml")

if template is not None:
    if template.tag != "Container" or template.attrib.get("version") != "2":
        fail("template root must be Container version 2")
    for tag in ("Name", "Repository", "Network", "TemplateURL", "Overview", "Description"):
        element = template.find(tag)
        if element is None or not (element.text or "").strip():
            fail(f"template is missing non-empty <{tag}>")
    network = template.find("Network")
    if network is not None and (network.text or "").strip() != "host":
        fail("template Network must be host")
    configs = list(template.findall("Config"))
    if not configs:
        fail("template has no Config entries")
    key_masked = False
    settings_target = False
    for config in configs:
        name = config.attrib.get("Name", "")
        if config.attrib.get("Type") == "Port":
            fail(f"host-network template has a Port config: {name}")
        for attr in ("Name", "Target", "Type"):
            if not config.attrib.get(attr):
                fail(f"Config {name or '(unnamed)'} is missing {attr}")
        if config.attrib.get("Target") == "EUGEN_DEDICATED_KEY":
            key_masked = config.attrib.get("Mask") == "true"
        if config.attrib.get("Target") == "/server/settings":
            settings_target = True
        description = config.attrib.get("Description", "")
        if len(description) > 240:
            fail(f"templates/warhost.xml: {name} description is {len(description)} characters")
        folded = description.lower()
        if "<br" in folded or "&lt;br" in folded:
            fail(f"templates/warhost.xml: {name} description contains a br tag")
    if not key_masked:
        fail("EUGEN_DEDICATED_KEY must be a Config with Mask=true")
    if not settings_target:
        fail("settings Config target must be /server/settings")
    text = (root / "templates/warhost.xml").read_text()
    for number, line in enumerate(text.splitlines(), 1):
        if "<Config " in line and "</Config>" not in line:
            fail(f"templates/warhost.xml:{number}: Config must stay on one line")
        if "<Networking" in line or "<Environment" in line or "<Data>" in line:
            fail(f"templates/warhost.xml:{number}: legacy template block")

if profile is not None:
    if profile.tag != "CommunityApplications":
        fail("ca_profile.xml root must be CommunityApplications")
    for tag in ("Profile", "Icon", "WebPage", "Forum"):
        element = profile.find(tag)
        if element is None or not (element.text or "").strip():
            fail(f"ca_profile.xml is missing non-empty <{tag}>")

allowed_keys = {
    "YOUR_EUGEN_DEDICATED_KEY_HERE",
    "%s",
    "host-key-value",
}
allowed_logins = {
    "YOUR_EUGEN_LOGIN_HERE",
    "%s",
    "host-login",
}
# Full-line ini assignments only, so format strings in the wrapper are not treated as keys.
key_pattern = re.compile(r'^\s*dedicated_key="([^"]*)"\s*$')
login_pattern = re.compile(r'^\s*login="([^"]*)"\s*$')
tracked = subprocess.check_output(
    ["git", "ls-files", "-z", "-c", "-o", "--exclude-standard"],
    cwd=root,
)
for raw in tracked.split(b"\0"):
    if not raw:
        continue
    relative = raw.decode()
    if relative == "login.ini" or relative.endswith("/login.ini"):
        fail(f"tracked login.ini: {relative}")
    path = root / relative
    if not path.is_file():
        continue
    try:
        file_text = path.read_text()
    except UnicodeDecodeError:
        continue
    for number, line in enumerate(file_text.splitlines(), 1):
        for match in key_pattern.finditer(line):
            if match.group(1) not in allowed_keys:
                fail(f"{relative}:{number}: unexpected dedicated_key assignment")
        for match in login_pattern.finditer(line):
            if match.group(1) not in allowed_logins:
                fail(f"{relative}:{number}: unexpected login assignment")

def command_block(text):
    return "\n".join(line.strip() for line in text.splitlines() if line.strip())


def run_fetch(args):
    completed = subprocess.run(
        ["sh", "scripts/print_template_fetch.sh", *args],
        cwd=root,
        text=True,
        capture_output=True,
    )
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout).strip()
        fail(f"scripts/print_template_fetch.sh {' '.join(args)}: {detail}")
        return ""
    return completed.stdout


readme = (root / "README.md").read_text()
install_doc = (root / "docs/INSTALL-UNRAID.md").read_text()
fetch = run_fetch([])
private_fetch = run_fetch(["--private"])
if command_block(fetch) not in command_block(readme):
    fail("README.md is missing the output of scripts/print_template_fetch.sh")
if command_block(fetch) not in command_block(install_doc):
    fail("docs/INSTALL-UNRAID.md is missing the output of scripts/print_template_fetch.sh")
if command_block(private_fetch) not in command_block(install_doc):
    fail("docs/INSTALL-UNRAID.md is missing the output of scripts/print_template_fetch.sh --private")
if "scripts/print_template_fetch.sh" not in readme:
    fail("README.md does not name scripts/print_template_fetch.sh")

if errors:
    print("repository check failed:", file=sys.stderr)
    for message in errors:
        print(f"- {message}", file=sys.stderr)
    sys.exit(1)

print("repository invariants ok")
print("XML parse recorded. Unraid install behavior was not tested.")
PY

sh -n entrypoint-unraid.sh
sh -n tests/entrypoint_test.sh
sh -n scripts/check_repo.sh
sh -n scripts/print_template_fetch.sh
python3 -c 'import pathlib; compile(pathlib.Path("scripts/upstream_digest.py").read_text(), "scripts/upstream_digest.py", "exec")'
echo "syntax ok"

sh tests/entrypoint_test.sh
