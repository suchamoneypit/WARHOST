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
clean = False
template_arg = None
branches = []

usage = (
    "usage: sh scripts/print_template_fetch.sh [--private] [--clean] [--branch NAME]... [templates/name.xml]\n"
    "\n"
    "Print the command to paste into the Unraid web terminal.\n"
    "Default saves my-<Name>.xml under dockerMan user templates.\n"
    "The Template dropdown shows that filename with a leading my- removed.\n"
    "--branch NAME replaces the ref in a raw.githubusercontent.com TemplateURL.\n"
    "The ref already in that URL keeps my-<Name>.xml. Any other branch is saved\n"
    "as my-<Name>-NAME.xml. Each branch is its own script.\n"
    "--private saves the repository filename where the Apps tab lists private templates.\n"
    "A non-default branch then uses that filename with -NAME before .xml.\n"
    "--clean prints a script that removes those containers, their template files,\n"
    "and their /mnt/user/appdata/warno/<port>/settings folders.\n"
    "It removes the template image only when no container is still using it.\n"
    "A settings folder still mounted by another container is left in place."
)

args = sys.argv[2:]
index = 0
while index < len(args):
    arg = args[index]
    if arg == "--private":
        private = True
    elif arg == "--clean":
        clean = True
    elif arg in ("-h", "--help"):
        print(usage)
        sys.exit(0)
    elif arg == "--branch":
        if index + 1 >= len(args) or args[index + 1].startswith("-"):
            print("--branch needs a name", file=sys.stderr)
            sys.exit(2)
        index += 1
        branches.append(args[index])
    elif arg.startswith("--branch="):
        value = arg.split("=", 1)[1]
        if not value:
            print("--branch needs a name", file=sys.stderr)
            sys.exit(2)
        branches.append(value)
    elif arg.startswith("-"):
        print(f"unknown option: {arg}", file=sys.stderr)
        sys.exit(2)
    elif template_arg is None:
        template_arg = arg
    else:
        print("too many arguments", file=sys.stderr)
        sys.exit(2)
    index += 1

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

parts = url.split("/")
# https://raw.githubusercontent.com/<owner>/<repo>/<ref>/...
github = len(parts) >= 7 and parts[2] == "raw.githubusercontent.com" and parts[3]

user_dir = "/boot/config/plugins/dockerMan/templates-user"
user_file = f"my-{container}.xml"
if github:
    private_dir = f"/boot/config/plugins/community.applications/private/{parts[3]}"
    private_file = name
else:
    private_dir = ""
    private_file = ""

if private:
    if not github:
        print(
            "--private needs a raw.githubusercontent.com TemplateURL",
            file=sys.stderr,
        )
        sys.exit(1)
    dest_dir = private_dir
    dest_file = private_file
else:
    dest_dir = user_dir
    dest_file = user_file

default_ref = parts[5] if github else ""


def require_branch(branch):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", branch):
        print(
            f"branch name is not safe for a flash filename: {branch}",
            file=sys.stderr,
        )
        sys.exit(2)


def branch_url(branch):
    if not github:
        print(
            "--branch needs a raw.githubusercontent.com TemplateURL",
            file=sys.stderr,
        )
        sys.exit(1)
    require_branch(branch)
    rewritten = parts.copy()
    rewritten[5] = branch
    return "/".join(rewritten)


def suffixed(filename, branch):
    if branch == default_ref:
        return filename
    return f"{filename[:-4]}-{branch}.xml"


def dest_for(branch):
    return suffixed(dest_file, branch)


seen = []
for branch in branches:
    if branch not in seen:
        seen.append(branch)


def quote(value):
    if value.startswith("-") or ".." in value or not re.fullmatch(r"[A-Za-z0-9_.:/@+-]+", value):
        print(f"refusing to embed this in a shell script: {value}", file=sys.stderr)
        sys.exit(1)
    return f"'{value}'"


def emit_download(dest_name, file_url):
    return "\n".join(
        [
            f"mkdir -p {dest_dir}",
            f"curl -fsSL -o {dest_dir}/{dest_name} \\",
            f"  {file_url}",
        ]
    )


def emit_clean():
    repository = (document.getroot().findtext("Repository") or "").strip()
    if not repository:
        print("Repository is empty", file=sys.stderr)
        sys.exit(1)
    quote(repository)

    targets = seen if seen else ([default_ref] if default_ref else [])
    for branch in targets:
        require_branch(branch)
    container_names = [container]
    files = []
    if targets:
        for branch in targets:
            label = container if branch == default_ref else f"{container}-{branch}"
            if label not in container_names:
                container_names.append(label)
            files.append(f"{user_dir}/{suffixed(user_file, branch)}")
            if private_dir:
                files.append(f"{private_dir}/{suffixed(private_file, branch)}")
    else:
        files.append(f"{user_dir}/{user_file}")

    settings_path = ""
    for config in document.getroot().findall("Config"):
        if (config.attrib.get("Target") or "") == "/server/settings":
            settings_path = (config.text or config.attrib.get("Default") or "").strip()
            break
    if not settings_path:
        print("Settings Folder path is empty", file=sys.stderr)
        sys.exit(1)
    quote(settings_path)

    names = " ".join(quote(item) for item in container_names)
    file_list = " \\\n  ".join(quote(path) for path in files)
    lines = [
        "# Removes these containers, their template files, and their settings folders.",
        "# Removes the image only when no container is still using it.",
        "# Removes only /mnt/user/appdata/warno/<port>/settings for these containers.",
        "# A settings folder still mounted by another container is left in place.",
        f"image={quote(repository)}",
        "settings_list=$(mktemp) || settings_list=",
        "add_settings() {",
        "  path=${1%/}",
        '  case "$path" in',
        "    /mnt/user/appdata/warno/*/settings) ;;",
        "    '') return ;;",
        "    *) printf '%s\\n' \"left settings path in place: $path\" >&2; return ;;",
        "  esac",
        "  rest=${path#/mnt/user/appdata/warno/}",
        "  port=${rest%/settings}",
        "  printf '%s\\n' \"$port\" | grep -Eq '^[0-9]+$' || {",
        "    printf '%s\\n' \"left settings path in place: $path\" >&2",
        "    return",
        "  }",
        '  if [ -n "$settings_list" ]; then',
        "    printf '%s\\n' \"$path\" >> \"$settings_list\"",
        "  fi",
        "}",
        f"add_settings {quote(settings_path)}",
        f"for name in {names}; do",
        '  if docker inspect "$name" >/dev/null 2>&1; then',
        "    docker inspect --format '{{range .Mounts}}{{if eq .Destination \"/server/settings\"}}{{println .Source}}{{end}}{{end}}' \"$name\" |",
        "      while IFS= read -r mounted; do",
        '        add_settings "$mounted"',
        "      done",
        '    docker stop "$name" || true',
        '    if docker rm -f "$name"; then',
        '      echo "removed container $name"',
        "    else",
        '      echo "left container $name in place" >&2',
        "    fi",
        "  else",
        '    echo "no container $name"',
        "  fi",
        "done",
        "autostart=/var/lib/docker/unraid-autostart",
        'if [ -f "$autostart" ]; then',
        '  tmp=$(mktemp) || { echo "left $autostart unchanged"; tmp=; }',
        '  if [ -n "$tmp" ]; then',
        '    while IFS= read -r line || [ -n "$line" ]; do',
        '      field=${line%%[[:space:]]*}',
        "      keep=yes",
        f"      for name in {names}; do",
        '        if [ "$field" = "$name" ]; then',
        "          keep=no",
        "        fi",
        "      done",
        '      if [ "$keep" = yes ]; then',
        "        printf '%s\\n' \"$line\"",
        "      else",
        '        echo "removed autostart $field" >&2',
        "      fi",
        '    done < "$autostart" > "$tmp"',
        '    cat "$tmp" > "$autostart"',
        '    rm -f "$tmp"',
        "  fi",
        "else",
        '  echo "no autostart file"',
        "fi",
        'if ! in_use=$(docker ps -a --filter "ancestor=$image" --format \'{{.Names}}\'); then',
        '  echo "left image $image in place; could not list containers"',
        'elif [ -n "$in_use" ]; then',
        '  echo "left image $image in place; still used by:"',
        '  printf \'%s\\n\' "$in_use"',
        'elif docker image inspect "$image" >/dev/null 2>&1; then',
        '  if docker rmi "$image"; then',
        '    echo "removed image $image"',
        "  else",
        '    echo "left image $image in place"',
        "  fi",
        "else",
        '  echo "no image $image"',
        "fi",
        "for file in \\",
        f"  {file_list}",
        "do",
        '  if [ -f "$file" ]; then',
        "    mounted=$(sed -n 's/.*Target=\"\\/server\\/settings\"[^>]*>\\([^<]*\\)<\\/Config>.*/\\1/p' \"$file\" | head -n 1)",
        '    if [ -z "$mounted" ]; then',
        "      mounted=$(sed -n 's/.*Target=\"\\/server\\/settings\"[^>]*Default=\"\\([^\"]*\\)\".*/\\1/p' \"$file\" | head -n 1)",
        "    fi",
        '    add_settings "$mounted"',
        "  fi",
        "done",
        "for file in \\",
        f"  {file_list}",
        "do",
        '  if [ -f "$file" ]; then',
        '    rm -f "$file"',
        '    echo "removed $file"',
        "  else",
        '    echo "no file $file"',
        "  fi",
        "done",
        'if [ -z "$settings_list" ]; then',
        "  echo \"left settings folders in place; could not make a list\" >&2",
        "elif ! docker ps -a --format '{{.Names}}' > \"${settings_list}.names\"; then",
        "  echo \"left settings folders in place; could not list containers\" >&2",
        "  rm -f \"$settings_list\" \"${settings_list}.names\"",
        "else",
        "  sort -u \"$settings_list\" | while IFS= read -r path; do",
        '    [ -n "$path" ] || continue',
        "    holder=",
        "    while IFS= read -r other; do",
        '      [ -n "$other" ] || continue',
        "      if ! src=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination \"/server/settings\"}}{{println .Source}}{{end}}{{end}}' \"$other\" 2>/dev/null); then",
        "        holder=$other",
        "        break",
        "      fi",
        "      src=$(printf '%s\\n' \"$src\" | head -n 1)",
        "      src=${src%/}",
        '      if [ "$src" = "$path" ]; then',
        "        holder=$other",
        "        break",
        "      fi",
        "    done < \"${settings_list}.names\"",
        '    if [ -n "$holder" ]; then',
        "      printf '%s\\n' \"left settings $path in place; still used by $holder\" >&2",
        '    elif [ -d "$path" ] || [ -L "$path" ]; then',
        '      if rm -rf "$path"; then',
        "        printf '%s\\n' \"removed settings $path\"",
        "      else",
        "        printf '%s\\n' \"left settings $path in place\" >&2",
        "      fi",
        "    else",
        "      printf '%s\\n' \"no settings $path\"",
        "    fi",
        "  done",
        "  rm -f \"$settings_list\" \"${settings_list}.names\"",
        "fi",
    ]
    return "\n".join(lines)


if clean:
    print(emit_clean())
else:
    if not seen:
        downloads = [(dest_file, url)]
    else:
        downloads = [(dest_for(branch), branch_url(branch)) for branch in seen]
    print("\n\n".join(emit_download(dest_name, file_url) for dest_name, file_url in downloads))
PY
