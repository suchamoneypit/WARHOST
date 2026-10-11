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
    key_visible = False
    settings_target = False
    for config in configs:
        name = config.attrib.get("Name", "")
        if config.attrib.get("Type") == "Port":
            fail(f"host-network template has a Port config: {name}")
        for attr in ("Name", "Target", "Type"):
            if not config.attrib.get(attr):
                fail(f"Config {name or '(unnamed)'} is missing {attr}")
        if config.attrib.get("Target") == "EUGEN_KEY_LAST4":
            fail("EUGEN_KEY_LAST4 must not be a template field")
        if config.attrib.get("Target") == "EUGEN_DEDICATED_KEY":
            key_visible = config.attrib.get("Mask") == "false"
        if config.attrib.get("Target") == "/server/settings":
            settings_target = True
        description = config.attrib.get("Description", "")
        if len(description) > 240:
            fail(f"templates/warhost.xml: {name} description is {len(description)} characters")
        folded = description.lower()
        if "<br" in folded or "&lt;br" in folded:
            fail(f"templates/warhost.xml: {name} description contains a br tag")
    if not key_visible:
        fail("EUGEN_DEDICATED_KEY must be a Config with Mask=false")
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

license_path = root / "LICENSE"
if not license_path.is_file():
    fail("LICENSE is missing from the repository root")
else:
    license_text = license_path.read_text()
    if "[year]" in license_text or "[fullname]" in license_text:
        fail("LICENSE still has the Community Apps starter copyright placeholder")
    if not license_text.startswith("MIT License\n"):
        fail("LICENSE must start with the standard MIT heading so GitHub can detect it")
    if "Permission is hereby granted, free of charge, to any person obtaining a copy" not in license_text:
        fail("LICENSE is missing the MIT permission sentence")
    if 'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND' not in license_text:
        fail("LICENSE is missing the MIT warranty sentence")

if template is not None:
    readme_url = template.find("ReadMe")
    license_url = template.find("License")
    expected_readme = "https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/README.md"
    expected_license = "https://raw.githubusercontent.com/suchamoneypit/WARHOST/main/LICENSE"
    if readme_url is None or (readme_url.text or "").strip() != expected_readme:
        fail(f"template ReadMe must be {expected_readme}")
    if license_url is None or (license_url.text or "").strip() != expected_license:
        fail(f"template License must be {expected_license}")

dockerfile_text = (root / "Dockerfile").read_text()
if "org.opencontainers.image.licenses" in dockerfile_text:
    fail("Dockerfile must leave the image license unlabeled; LICENSE covers the repository files")

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

main_branch = run_fetch(["--branch", "main"])
if command_block(main_branch) != command_block(fetch):
    fail("scripts/print_template_fetch.sh --branch main does not match the default command")

name_match = re.search(r"/my-([A-Za-z0-9][A-Za-z0-9_.-]*)\.xml", fetch)
if not name_match:
    fail("scripts/print_template_fetch.sh did not save my-<Name>.xml")
else:
    container = name_match.group(1)
    for branch in ("dev", "webui"):
        branched = run_fetch(["--branch", branch])
        if f"/{branch}/templates/" not in branched:
            fail(f"scripts/print_template_fetch.sh --branch {branch} did not rewrite the ref")
        if f"my-{container}-{branch}.xml" not in branched:
            fail(f"scripts/print_template_fetch.sh --branch {branch} did not suffix the filename")
        if f"/main/templates/" in branched:
            fail(f"scripts/print_template_fetch.sh --branch {branch} still points at main")
    all_branches = run_fetch(["--branch", "main", "--branch", "dev", "--branch", "webui"])
    for needle in (
        f"/main/templates/",
        f"/dev/templates/",
        f"/webui/templates/",
        f"my-{container}.xml",
        f"my-{container}-dev.xml",
        f"my-{container}-webui.xml",
    ):
        if needle not in all_branches:
            fail(f"branch download is missing {needle}")
    if f"my-{container}-main.xml" in all_branches:
        fail("the TemplateURL ref was saved under a branch suffix")
    blocks = [block for block in all_branches.split("\n\n") if block.strip()]
    if len(blocks) != 3:
        fail("main, dev, and webui downloads were not three separate scripts")
    for block, branch in zip(blocks, ("main", "dev", "webui")):
        if block.count("curl ") != 1 or f"/{branch}/templates/" not in block:
            fail(f"the {branch} download is not its own script")

private_main = run_fetch(["--private", "--branch", "main"])
if command_block(private_main) != command_block(private_fetch):
    fail("scripts/print_template_fetch.sh --private --branch main does not match --private")

clean = run_fetch(["--clean", "--branch", "main", "--branch", "dev", "--branch", "webui"])
if template is None:
    fail("clean script was not checked because the template did not parse")
elif not name_match:
    fail("clean script was not checked because the default download had no my-<Name>.xml")
else:
    repository = (template.findtext("Repository") or "").strip()
    template_url = (template.findtext("TemplateURL") or "").strip()
    private_name = template_url.rstrip("/").rsplit("/", 1)[-1]
    for needle in (
        f"'{container}'",
        f"'{container}-dev'",
        f"'{container}-webui'",
        f"my-{container}.xml",
        f"my-{container}-dev.xml",
        f"my-{container}-webui.xml",
        private_name,
        f"{private_name[:-4]}-dev.xml",
        f"{private_name[:-4]}-webui.xml",
        repository,
        "/var/lib/docker/unraid-autostart",
        "docker stop",
        "docker rm -f",
        'docker rmi "$image"',
        "ancestor=$image",
        'rm -rf "$path"',
        "/mnt/user/appdata/warno/*/settings",
    ):
        if needle not in clean:
            fail(f"clean script is missing {needle}")
    settings_path = ""
    for config in template.findall("Config"):
        if (config.attrib.get("Target") or "") == "/server/settings":
            settings_path = (config.text or "").strip()
    if not settings_path or settings_path not in clean:
        fail("clean script does not name the template Settings Folder path")
    rm_rf = [line.strip() for line in clean.splitlines() if "rm -rf" in line]
    if rm_rf != ['if rm -rf "$path"; then']:
        fail(f"clean script rm -rf is not limited to the settings path: {rm_rf}")
    if any(token in clean for token in ("system prune", "rmi -f", "curl ")):
        fail("clean script deletes more than the named containers, image, template files, and settings folders")

unsafe = subprocess.run(
    ["sh", "scripts/print_template_fetch.sh", "--branch", "dev/evil"],
    cwd=root,
    text=True,
    capture_output=True,
)
if unsafe.returncode == 0:
    fail("scripts/print_template_fetch.sh accepted a branch name with a slash")

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
python3 -c 'import pathlib; compile(pathlib.Path("scripts/next_version.py").read_text(), "scripts/next_version.py", "exec")'
python3 -c 'import pathlib; compile(pathlib.Path("scripts/list_workshop_mods.py").read_text(), "scripts/list_workshop_mods.py", "exec")'
echo "syntax ok"

expect_version() {
  expected=$1
  shift
  actual=$(python3 scripts/next_version.py "$@")
  if [ "$actual" != "$expected" ]; then
    echo "next_version.py $* expected ${expected} got ${actual}" >&2
    exit 1
  fi
}

expect_version 0.90 --tags
expect_version 0.91 --tags v0.90
expect_version 1.00 --tags v0.99
expect_version 1.00 --tags v0.94 --set 1.0
expect_version 1.01 --tags v1.00 --set 1.00
expect_version 0.90 --points-at v0.90 --tags v0.90
expect_version 0.90 --points-at v0.90 v0.91 --tags v0.91
expect_version 0.95 --tags v0.94 --set 0.90
expect_version 1.04 --tags v1.03 --set 1.02
echo "version numbering ok"

python3 scripts/list_workshop_mods.py --self-test

sh tests/entrypoint_test.sh
