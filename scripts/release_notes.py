#!/usr/bin/env python3
"""Print the GitHub Release notes for one WARHOST version.

From the repository root:

  python3 scripts/release_notes.py --tag v1.13
  python3 scripts/release_notes.py --tag v1.13 --to <commit>
  python3 scripts/release_notes.py --apply

The summaries below are what a host would notice in that version. A tag with
no summary is an error, so the release job stops before it pushes a tag.
--to is accepted and ignored; the notes do not list commit subjects. The
compare link is last.

--apply writes those notes onto the existing GitHub releases with `gh`.
--self-test checks the summaries.
"""

import argparse
import os
import subprocess
import sys
import tempfile

import next_version

REPO = "https://github.com/suchamoneypit/WARHOST"

# What a host would notice. A later tag is added here in the publish that
# creates it. The workflow does not invent notes from commit subjects.
WRITTEN = {
    "v0.90": (
        "- First release of the Unraid template. It writes the login and lobby files, then starts Eugen's WARNO server.\n"
        "- The container uses host networking. Each server has its own settings folder and game port, and a second container will not start if that port or folder is already in use.\n"
        "- The preset server is WARHOST - Red Dragon 4v4 on RDPort_JungleLaw_2v2_CONQ, with workshop mod 3811913066/15."
    ),
    "v0.91": (
        "- Map is on the main Docker form, under Server Name.\n"
        "- Settings are written beside the settings folder and moved into place, so a symlink there cannot redirect the dedicated key."
    ),
    "v1.00": (
        "- A new server's settings folder includes its game port. The default is /mnt/user/appdata/warno/10400/settings, and the next container uses the next port in that path."
    ),
    "v1.01": (
        "- The template, docs, and wrapper are under the MIT license. Eugen's server image keeps its own license."
    ),
    "v1.02": (
        "- A new container uses the base-game map Hesse (_2x2_Hesse_2vs2_CONQ) and no workshop mods.\n"
        "- Clearing Workshop Mod List or Workshop Mod Tags leaves them empty. On a container created from an older template, none still clears those fields."
    ),
    "v1.03": "- No change to the server or the Unraid form.",
    "v1.04": (
        "- A Workshop Mod List entry that is only an id, such as 3811913066, is written as id/Version from that mod's Config.ini on each start.\n"
        "- An entry that already includes a version is left as written.\n"
        "- If that version cannot be read and no earlier version was saved, the server does not start."
    ),
    "v1.05": (
        "- The install instructions include one Unraid paste for the main template and one for the dev template.\n"
        "- The clean-slate reset removes those containers, their template files, and their settings folders."
    ),
    "v1.06": (
        "- Optional Lobby Page, off by default. It saves the lobby without stopping the dedicated server.\n"
        "- The page listens on the game port plus 1000 (11400 when the game port is 10400). The Docker log names that port, including when the page is down."
    ),
    "v1.07": (
        "- The Docker field Lobby Page is renamed to WebUI.\n"
        "- A modded map is listed only when its workshop pack is enabled.\n"
        "- The Community Apps install popup asks for the Eugen login and dedicated key."
    ),
    "v1.10": (
        "- The WebUI is on by default. Server name, map, player counts, combat rule, and workshop mods are edited there, and those fields left the Docker form.\n"
        "- A new server is named WARHOST - default server name until that name is changed.\n"
        "- Workshop mods are split into map packs and other mods.\n"
        "- Saving a listed map keeps that scenario's combat rule.\n"
        "- Save and restart reloads the dedicated server, and asks again when nothing changed.\n"
        "- Player limits stay editable, so a smaller match can run on a larger map."
    ),
    "v1.11": "- No change to the server, the Unraid form, or the WebUI.",
    "v1.12": (
        "- The WebUI can set up a PvP or PvE lobby. A PvE save keeps the AI decks across restarts.\n"
        "- The map list is a short picker.\n"
        "- Map packs are listed under Steam Workshop Maps."
    ),
    "v1.13": "- No change to the server, the Unraid form, or the WebUI.",
    "v1.14": (
        "- Save and restart still shows the lobby after it pins a Workshop id. A page port left in TIME_WAIT does not keep the page from starting.\n"
        "- The Docker log and the Unraid form descriptions are shorter.\n"
        "- Support opens the Unraid forum thread."
    ),
}

REQUIRED = {
    "v0.90": "3811913066/15",
    "v0.91": "symlink",
    "v1.00": "/mnt/user/appdata/warno/10400/settings",
    "v1.01": "MIT",
    "v1.02": "_2x2_Hesse_2vs2_CONQ",
    "v1.03": "No change to the server or the Unraid form.",
    "v1.04": "Config.ini",
    "v1.05": "clean-slate",
    "v1.06": "11400",
    "v1.07": "WebUI",
    "v1.10": "Save and restart",
    "v1.11": "No change to the server, the Unraid form, or the WebUI.",
    "v1.12": "PvE",
    "v1.13": "No change to the server, the Unraid form, or the WebUI.",
    "v1.14": "forum thread",
}


def previous_version_tag(tag, tags):
    target = next_version.parse_version(tag)
    found = []
    for item in tags:
        try:
            version = next_version.parse_version(item)
        except ValueError:
            continue
        if version < target:
            found.append(version)
    if not found:
        return None
    return "v{0}".format(next_version.format_version(max(found)))


def changelog_line(previous, tag):
    if previous is None:
        url = "{0}/commits/{1}".format(REPO, tag)
    else:
        url = "{0}/compare/{1}...{2}".format(REPO, previous, tag)
    return "**Full Changelog**: {0}".format(url)


def render(tag, previous):
    next_version.parse_version(tag)
    if tag not in WRITTEN:
        raise ValueError(
            "no written summary for {0}. Add what a host would notice to scripts/release_notes.py".format(tag)
        )
    return "{0}\n\n{1}\n".format(WRITTEN[tag].rstrip(), changelog_line(previous, tag))


def git_tags():
    completed = subprocess.run(
        ["git", "tag", "--list"],
        cwd=str(next_version.ROOT),
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout).strip()
        raise ValueError(detail or "git tag --list failed")
    return [line.strip() for line in completed.stdout.splitlines() if line.strip()]


def notes_for(tag, to=None, tags=None):
    del to
    if tags is None:
        tags = git_tags()
    previous = previous_version_tag(tag, tags)
    return render(tag, previous)


def apply_github():
    tags = list(WRITTEN)
    for tag in tags:
        body = notes_for(tag, tags=tags)
        handle = tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False)
        try:
            handle.write(body)
            handle.close()
            completed = subprocess.run(
                ["gh", "release", "edit", tag, "--notes-file", handle.name],
                cwd=str(next_version.ROOT),
                check=False,
                capture_output=True,
                text=True,
            )
        finally:
            os.unlink(handle.name)
        if completed.returncode != 0:
            detail = (completed.stderr or completed.stdout).strip()
            raise ValueError("{0}: {1}".format(tag, detail or "gh release edit failed"))
        print(tag)


def self_test():
    tags = list(WRITTEN)
    if list(REQUIRED) != tags:
        print("self-test required phrases do not match the written tags", file=sys.stderr)
        return 1
    if previous_version_tag("v1.10", tags) != "v1.07":
        print("self-test previous tag for v1.10", file=sys.stderr)
        return 1
    if previous_version_tag("v1.13", tags) != "v1.12":
        print("self-test previous tag for v1.13", file=sys.stderr)
        return 1
    if previous_version_tag("v0.90", tags) is not None:
        print("self-test v0.90 should be the first tag", file=sys.stderr)
        return 1
    for tag in tags:
        previous = previous_version_tag(tag, tags)
        body = render(tag, previous)
        if REQUIRED[tag] not in body:
            print("self-test {0} missing {1!r}".format(tag, REQUIRED[tag]), file=sys.stderr)
            return 1
        line = changelog_line(previous, tag)
        if body.count(line) != 1 or not body.endswith(line + "\n"):
            print("self-test {0} changelog link".format(tag), file=sys.stderr)
            return 1
    try:
        render("v9.99", "v9.98")
    except ValueError as exc:
        if "v9.99" not in str(exc):
            print("self-test missing-summary error {0}".format(exc), file=sys.stderr)
            return 1
    else:
        print("self-test accepted a tag with no summary", file=sys.stderr)
        return 1
    return 0


def main(argv):
    parser = argparse.ArgumentParser(description="Print GitHub Release notes for a WARHOST version.")
    parser.add_argument("--tag", help="Version tag, such as v1.13.")
    parser.add_argument(
        "--to",
        help="Accepted for the release workflow. The notes do not list commits through this revision.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write the written summaries onto the GitHub releases with gh.",
    )
    parser.add_argument("--self-test", action="store_true", help="Check the summaries and exit.")
    args = parser.parse_args(argv)
    try:
        if args.self_test:
            return self_test()
        if args.apply:
            apply_github()
            return 0
        if not args.tag:
            print("release_notes.py: --tag is required", file=sys.stderr)
            return 1
        sys.stdout.write(notes_for(args.tag, args.to))
    except ValueError as exc:
        print("release_notes.py: {0}".format(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
