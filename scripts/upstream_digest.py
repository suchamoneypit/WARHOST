#!/usr/bin/env python3
"""Print the registry manifest digest of eugensystems/warno:latest."""

import json
import sys
import urllib.request


def fetch(url, headers):
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read(), response.headers


def main():
    token_body, _ = fetch(
        "https://auth.docker.io/token?service=registry.docker.io&scope=repository:eugensystems/warno:pull",
        {},
    )
    token = json.loads(token_body)["token"]
    _, headers = fetch(
        "https://registry-1.docker.io/v2/eugensystems/warno/manifests/latest",
        {
            "Authorization": "Bearer " + token,
            "Accept": ", ".join(
                [
                    "application/vnd.docker.distribution.manifest.v2+json",
                    "application/vnd.oci.image.manifest.v1+json",
                    "application/vnd.docker.distribution.manifest.list.v2+json",
                    "application/vnd.oci.image.index.v1+json",
                ]
            ),
        },
    )
    digest = headers.get("Docker-Content-Digest", "").strip()
    if len(digest) != 71 or not digest.startswith("sha256:"):
        print("Unexpected digest: {0!r}".format(digest), file=sys.stderr)
        return 1
    print(digest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
