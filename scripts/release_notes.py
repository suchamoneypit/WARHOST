#!/usr/bin/env python3
"""Print the GitHub Release notes for one WARHOST version.

From the repository root:

  python3 scripts/release_notes.py --tag v1.11
  python3 scripts/release_notes.py --tag v1.12 --to <commit>
  python3 scripts/release_notes.py --apply

Tags v0.90 through v1.11 use the written summaries below. A later tag lists
the commit subjects since the previous version tag. Wording-only subjects are
left out. The compare link is last.

--apply writes those notes onto the existing GitHub releases with `gh`.
--self-test checks the summaries and the commit-list fallback.
"""

import argparse
import os
import subprocess
import sys
import tempfile

import next_version

REPO = "https://github.com/suchamoneypit/WARHOST"
# Subjects that do not tell a host what changed.
NOISE = {
    ".",
    "Update README.md",
    "wording changes",
    "slightly improved wording",
    "updated wording",
    "changed wording on unraid template xml",
    "updated README wording",
}

# Written once, from the commits in that tag's range. A later tag is not
# added here; the workflow lists its commit subjects instead.
WRITTEN = {
    "v0.90": (
        "First numbered release of the Unraid template. It writes the dedicated "
        "server's login and lobby files, then starts Eugen's WARNO image. The "
        "container uses host networking. Each server has its own settings folder "
        "and game port, and a second container refuses to start when that port or "
        "folder is already in use. The preset server name is WARHOST - Red Dragon 4v4, the "
        "map is RDPort_JungleLaw_2v2_CONQ, and the workshop list is 3811913066/15. "
        "Map and mod catalogs are in the README."
    ),
    "v0.91": (
        "Map is on the main Docker form, under Server Name. Settings are written "
        "in a private directory and then renamed into place, so a symlink in the "
        "settings folder cannot redirect the dedicated key."
    ),
    "v1.00": (
        "The settings folder for a new server includes the game port. The default "
        "path is /mnt/user/appdata/warno/10400/settings, and the next container "
        "uses the next port in that path."
    ),
    "v1.01": (
        "The repository LICENSE is MIT for the template, docs, and wrapper, for "
        "the Community Apps submission. Eugen's image keeps its own license."
    ),
    "v1.02": (
        "A new container defaults to the base-game map Hesse "
        "(_2x2_Hesse_2vs2_CONQ) with empty workshop fields. Clearing Workshop "
        "Mod List or Workshop Mod Tags stays empty, so a base-game server stays "
        "free of the Red Dragon pack. On a container created from "
        "an older template, `none` still clears those fields."
    ),
    "v1.03": (
        "Records the lobby page plan in the repository. The Unraid template and "
        "the server image stay as they were in v1.02."
    ),
    "v1.04": (
        "A Workshop Mod List value that is only an id, such as 3811913066, is "
        "rewritten to id/Version on each start from that mod's Config.ini. A "
        "value that already includes a version is left as written. When that "
        "Version cannot be read and no earlier Version is saved, the server "
        "does not start. A VERSION file older than the latest tag is ignored, and the "
        "release still takes the next minor number."
    ),
    "v1.05": (
        "The install instructions print one Unraid paste for the main template "
        "and one for the dev template, plus a clean-slate reset. That reset "
        "removes those containers, their template files, and their settings "
        "folders. The README is trimmed back to the map reference."
    ),
    "v1.06": (
        "Adds an optional Lobby Page, off by default. When it is on, it writes "
        "variables.ini without stopping the dedicated server, at the game port "
        "plus 1000 (10400 uses 11400). The Docker log names that listen port, "
        "including when the page is down."
    ),
    "v1.07": (
        "The Docker field is renamed from Lobby Page to WebUI. The map list "
        "shows a modded scenario only when that workshop pack is already "
        "enabled. The Community Apps requirements popup asks for the Eugen "
        "login and dedicated key."
    ),
    "v1.10": (
        "The WebUI is on by default and is where the lobby is edited: server "
        "name, map, player counts, combat rule, and workshop mods. Those fields "
        "left the Docker form. A new server is named WARHOST - default server "
        "name until that name is changed. Workshop mods are split into map packs "
        "and other mods. The published template installs "
        "ghcr.io/suchamoneypit/warhost:latest.\n\n"
        "Saving a listed map keeps that scenario's combat rule. Save and restart "
        "reloads the dedicated server, and asks again when nothing changed. "
        "Player limits stay editable, so a smaller match can run on a larger map."
    ),
    "v1.11": (
        "The privilege-drop test copies the WebUI page out of the runner home so "
        "the warhost-web user can read it. The server, the template, and the "
        "image stay as they were in v1.10."
    ),
}

REQUIRED = {
    "v0.90": "3811913066/15",
    "v0.91": "symlink",
    "v1.00": "/mnt/user/appdata/warno/10400/settings",
    "v1.01": "MIT",
    "v1.02": "_2x2_Hesse_2vs2_CONQ",
    "v1.03": "lobby page plan",
    "v1.04": "Config.ini",
    "v1.05": "clean-slate",
    "v1.06": "11400",
    "v1.07": "WebUI",
    "v1.10": "Save and restart",
    "v1.11": "warhost-web",
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


def summarize_subjects(subjects):
    kept = [subject for subject in subjects if subject not in NOISE]
    if not subjects:
        return "No changes since the previous release."
    if not kept:
        return "Documentation wording only."
    return "\n".join("- {0}".format(subject) for subject in kept)


def render(tag, previous, subjects=None):
    next_version.parse_version(tag)
    if tag in WRITTEN:
        summary = WRITTEN[tag]
    else:
        if subjects is None:
            raise ValueError("commit subjects are required for {0}".format(tag))
        summary = summarize_subjects(subjects)
    return "{0}\n\n{1}\n".format(summary.rstrip(), changelog_line(previous, tag))


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


def commit_subjects(previous, end):
    revision = end if previous is None else "{0}..{1}".format(previous, end)
    completed = subprocess.run(
        ["git", "log", "--no-merges", "--reverse", "--format=%s", revision],
        cwd=str(next_version.ROOT),
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout).strip()
        raise ValueError(detail or "git log failed")
    return [line.strip() for line in completed.stdout.splitlines() if line.strip()]


def notes_for(tag, to=None, tags=None):
    if tags is None:
        tags = git_tags()
    previous = previous_version_tag(tag, tags)
    subjects = None
    if tag not in WRITTEN:
        subjects = commit_subjects(previous, to or tag)
    return render(tag, previous, subjects)


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
    if previous_version_tag("v0.90", tags) is not None:
        print("self-test v0.90 should be the first tag", file=sys.stderr)
        return 1
    for tag in tags:
        previous = previous_version_tag(tag, tags)
        body = render(tag, previous, ["this subject must stay out of a written summary"])
        if REQUIRED[tag] not in body:
            print("self-test {0} missing {1!r}".format(tag, REQUIRED[tag]), file=sys.stderr)
            return 1
        if "this subject must stay out" in body:
            print("self-test {0} used commit subjects".format(tag), file=sys.stderr)
            return 1
        line = changelog_line(previous, tag)
        if body.count(line) != 1 or not body.endswith(line + "\n"):
            print("self-test {0} changelog link".format(tag), file=sys.stderr)
            return 1
    generated = render(
        "v9.99",
        "v9.98",
        [
            "Keep the real change.",
            "Update README.md",
            ".",
            "wording changes",
        ],
    )
    if "Keep the real change." not in generated:
        print("self-test dropped a real subject", file=sys.stderr)
        return 1
    if "Update README.md" in generated or "wording changes" in generated:
        print("self-test kept a wording subject", file=sys.stderr)
        return 1
    if not generated.endswith(changelog_line("v9.98", "v9.99") + "\n"):
        print("self-test generated changelog link", file=sys.stderr)
        return 1
    if summarize_subjects([]) != "No changes since the previous release.":
        print("self-test empty range", file=sys.stderr)
        return 1
    if summarize_subjects(["Update README.md", "."]) != "Documentation wording only.":
        print("self-test wording-only range", file=sys.stderr)
        return 1
    return 0


def main(argv):
    parser = argparse.ArgumentParser(description="Print GitHub Release notes for a WARHOST version.")
    parser.add_argument("--tag", help="Version tag, such as v1.11.")
    parser.add_argument("--to", help="Commit the notes run through. Defaults to the tag.")
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write the v0.90 through v1.11 notes onto the GitHub releases with gh.",
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
