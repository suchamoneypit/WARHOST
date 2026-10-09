#!/usr/bin/env python3
"""Print the next WARHOST release number as MAJOR.MINOR.

From the repository root, with no arguments, this reads `git tag` and the
optional VERSION file. Tests pass `--tags` so they do not use either.

The first number, when no version tag exists and VERSION is absent, is 0.90.
Otherwise the minor part gains one: 0.90 then 0.91, 0.99 then 1.00.
A VERSION value higher than the latest tag is used as written (1.0 is 1.00).
The same value as the latest tag increments. A lower value exits 1.
`--points-at` keeps the lowest version tag already on this commit.
"""

import argparse
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
VERSION_FILE = ROOT / "VERSION"
VERSION_TEXT = re.compile(r"^v?(0|[1-9][0-9]*)\.([0-9]{1,2})$")
FIRST = (0, 90)


def parse_version(text):
    match = VERSION_TEXT.fullmatch(text.strip())
    if match is None:
        raise ValueError("not a MAJOR.MINOR version: {0!r}".format(text.strip()))
    return int(match.group(1)), int(match.group(2))


def format_version(version):
    return "{0}.{1:02d}".format(version[0], version[1])


def bump(version):
    major, minor = version
    minor += 1
    if minor == 100:
        major += 1
        minor = 0
    return major, minor


def versions_in(tags):
    found = []
    for tag in tags:
        try:
            found.append(parse_version(tag))
        except ValueError:
            continue
    return found


def highest(tags):
    found = versions_in(tags)
    if not found:
        return None
    return max(found)


def decide(tags, override):
    current = highest(tags)
    if override is None:
        if current is None:
            return format_version(FIRST)
        return format_version(bump(current))
    if current is not None and override < current:
        raise ValueError(
            "{0} is not newer than {1}".format(
                format_version(override), format_version(current)
            )
        )
    if current is not None and override == current:
        return format_version(bump(current))
    return format_version(override)


def read_git_tags():
    completed = subprocess.run(
        ["git", "tag", "--list"],
        cwd=str(ROOT),
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout).strip()
        raise ValueError(detail or "git tag --list failed")
    return [line.strip() for line in completed.stdout.splitlines() if line.strip()]


def read_version_file():
    if not VERSION_FILE.is_file():
        return None
    text = VERSION_FILE.read_text().strip()
    if not text:
        return None
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if len(lines) != 1:
        raise ValueError("VERSION must be a single MAJOR.MINOR line")
    return parse_version(lines[0])


def main(argv):
    parser = argparse.ArgumentParser(description="Print the next WARHOST release number.")
    parser.add_argument(
        "--tags",
        nargs="*",
        default=None,
        help="Tag list to use instead of git. An empty list means no tags.",
    )
    parser.add_argument(
        "--set",
        dest="explicit",
        default=None,
        help="Explicit version. 1.0 is 1.00. Skips the VERSION file.",
    )
    parser.add_argument(
        "--points-at",
        nargs="*",
        default=None,
        dest="points_at",
        help="Tags already on this commit. A version tag is kept as-is.",
    )
    args = parser.parse_args(argv)
    try:
        if args.points_at is not None:
            already = versions_in(args.points_at)
            if already:
                print(format_version(min(already)))
                return 0
        tags = read_git_tags() if args.tags is None else args.tags
        if args.explicit is not None:
            override = parse_version(args.explicit)
        elif args.tags is None:
            override = read_version_file()
        else:
            override = None
        print(decide(tags, override))
    except ValueError as exc:
        print("next_version.py: {0}".format(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
