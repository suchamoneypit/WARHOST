#!/usr/bin/env python3
"""Print whether a main push should cut a WARHOST release.

Prints `release` or `skip`.

`release` when no version tag exists yet, when this commit already has a
version tag, or when the tree differs from the latest version tag in the
server, the Unraid template, the shipped WebUI, the image, VERSION, or
LICENSE. `skip` does not choose a number and does not need a summary.

The diff is against the latest version tag, not the previous commit. A
follow-up commit that only adds release notes still sees an untagged
product change and prints `release`.

  python3 scripts/release_scope.py
  python3 scripts/release_scope.py --names README.md
  python3 scripts/release_scope.py --publish
  python3 scripts/release_scope.py --self-test

`--publish` is the check `/publish` runs after `<Repository>` is `:latest`
and before it commits. It diffs the worktree and `origin/main` (or `main`)
against the latest version tag. Before that edit, the dev template differs
from the tagged template, so the command prints `release`.
"""

import argparse
import io
import subprocess
import sys

import next_version

# What a host runs or what Unraid shows as this server. A README or docs
# edit is not in this set.
EXACT = (
    "Dockerfile",
    "entrypoint-unraid.sh",
    "VERSION",
    "LICENSE",
)

# Copied into the image by the Dockerfile, or shown on the Unraid form.
# These WebUI paths are tests, the catalog generator, or gitignored output.
UNSHIPPED_WEBUI = (
    "webui/test_page.sh",
    "webui/make_catalog.py",
)
UNSHIPPED_WEBUI_PREFIXES = (
    "webui/previews/",
    "webui/run/",
)


def normalize(path):
    text = path.strip().replace("\\", "/")
    if text.startswith("./"):
        text = text[2:]
    if text.startswith("/"):
        return None
    parts = []
    for part in text.split("/"):
        if part in ("", "."):
            continue
        if part == "..":
            return None
        parts.append(part)
    if not parts:
        return None
    return "/".join(parts)


def is_worthy(path):
    normal = normalize(path)
    if normal is None:
        return False
    if normal in EXACT:
        return True
    if normal.startswith("templates/"):
        return True
    if not normal.startswith("webui/"):
        return False
    if normal in UNSHIPPED_WEBUI:
        return False
    if normal in ("webui/previews", "webui/run"):
        return False
    for prefix in UNSHIPPED_WEBUI_PREFIXES:
        if normal.startswith(prefix):
            return False
    return True


def decide(names, already_tagged=False, no_tags=False):
    if no_tags or already_tagged:
        return "release"
    for name in names:
        if is_worthy(name):
            return "release"
    return "skip"


def git_lines(args):
    completed = subprocess.run(
        ["git"] + args,
        cwd=str(next_version.ROOT),
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout).strip()
        raise ValueError(detail or "git {0} failed".format(" ".join(args)))
    return [line.strip() for line in completed.stdout.splitlines() if line.strip()]


def ref_exists(ref):
    completed = subprocess.run(
        ["git", "rev-parse", "-q", "--verify", ref],
        cwd=str(next_version.ROOT),
        check=False,
        capture_output=True,
        text=True,
    )
    return completed.returncode == 0


def latest_tag():
    current = next_version.highest(next_version.read_git_tags())
    if current is None:
        return None
    return "v{0}".format(next_version.format_version(current))


def from_git(publish):
    tag = latest_tag()
    if tag is None:
        return decide([], no_tags=True)
    if not publish:
        pointed = next_version.versions_in(git_lines(["tag", "--points-at", "HEAD"]))
        if pointed:
            return decide([], already_tagged=True)
        names = git_lines(["diff", "--name-only", tag, "HEAD"])
        return decide(names)
    names = git_lines(["diff", "--name-only", tag])
    other = None
    if ref_exists("origin/main"):
        other = "origin/main"
    elif ref_exists("main"):
        other = "main"
    if other is not None:
        names.extend(git_lines(["diff", "--name-only", tag, other]))
    return decide(names)


def self_test():
    cases = (
        (["--names"], "skip"),
        (["--names", "README.md"], "skip"),
        (["--names", "README.md", "docs/INSTALL-UNRAID.md"], "skip"),
        (["--names", "scripts/release_notes.py"], "skip"),
        (["--names", ".github/workflows/release.yml"], "skip"),
        (["--names", "ca_profile.xml", "icon.png"], "skip"),
        (["--names", "webui/test_page.sh"], "skip"),
        (["--names", "webui/make_catalog.py"], "skip"),
        (["--names", "webui/previews/hesse.webp"], "skip"),
        (["--names", "webui/../README.md"], "skip"),
        (["--names", "Dockerfile"], "release"),
        (["--names", "entrypoint-unraid.sh"], "release"),
        (["--names", "templates/warhost.xml"], "release"),
        (["--names", "webui/index.html"], "release"),
        (["--names", "./webui/server.py"], "release"),
        (["--names", "VERSION"], "release"),
        (["--names", "LICENSE"], "release"),
        (["--names", "README.md", "entrypoint-unraid.sh"], "release"),
        (["--names", "scripts/release_notes.py", "webui/lobby.py"], "release"),
    )
    for argv, expected in cases:
        code, output, err = capture(argv)
        if code != 0 or output != expected + "\n" or err:
            print(
                "self-test {0} expected {1} got {2!r} code {3} err {4!r}".format(
                    argv, expected, output, code, err
                ),
                file=sys.stderr,
            )
            return 1
    if decide(["README.md"], no_tags=True) != "release":
        print("self-test no tags should release", file=sys.stderr)
        return 1
    if decide(["README.md"], already_tagged=True) != "release":
        print("self-test an existing tag should release", file=sys.stderr)
        return 1
    code, output, err = capture(["--names", "--publish"])
    if code == 0 or "different modes" not in err:
        print(
            "self-test accepted --names with --publish: {0!r} {1!r}".format(output, err),
            file=sys.stderr,
        )
        return 1
    return 0


def capture(argv):
    old_out = sys.stdout
    old_err = sys.stderr
    sys.stdout = out = io.StringIO()
    sys.stderr = err = io.StringIO()
    try:
        code = main(argv)
    finally:
        sys.stdout = old_out
        sys.stderr = old_err
    return code, out.getvalue(), err.getvalue()


def main(argv):
    parser = argparse.ArgumentParser(description="Print whether a main push should cut a release.")
    parser.add_argument(
        "--names",
        nargs="*",
        default=None,
        help="Paths changed since the latest version tag. Skips git.",
    )
    parser.add_argument(
        "--publish",
        action="store_true",
        help="Diff the worktree and origin/main against the latest version tag.",
    )
    parser.add_argument("--self-test", action="store_true", help="Check the path rules and exit.")
    args = parser.parse_args(argv)
    try:
        if args.self_test:
            return self_test()
        if args.names is not None and args.publish:
            raise ValueError("--names and --publish are different modes")
        if args.names is not None:
            print(decide(args.names))
            return 0
        print(from_git(args.publish))
    except ValueError as exc:
        print("release_scope.py: {0}".format(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
