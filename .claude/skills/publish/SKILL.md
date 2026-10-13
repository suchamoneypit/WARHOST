---
name: publish
description: Publish the accumulated dev work to main (merge, optional VERSION, :latest template image). Cursor only, and only when the user explicitly asks to publish.
disable-model-invocation: true
---

# /publish

Publish the accumulated `dev` work to `main`. Run this only when the user explicitly asks to publish. Claude Code does not run this skill: it never commits, merges, or pushes. In Claude Code, say so and stop.

1. Run `git status --short`. Stop if the tree is dirty or the checkout is not `dev`. Run `sh scripts/check_repo.sh` and stop on a failure.
2. Version. If the request names a version, normalize it (`1.0` is `1.00`, `1.1` is `1.10`) into `VERSION`. Otherwise leave `VERSION` unchanged.
3. On `dev`, set `templates/warhost.xml` `<Repository>` to `ghcr.io/suchamoneypit/warhost:latest`. Commit that and any `VERSION` change as one commit ("Point the published template at the :latest image."), and push `origin/dev`.
4. Check out `main`, merge `dev`, push `origin/main`. Do not force-push.
5. Check out `dev`, set `<Repository>` back to `ghcr.io/suchamoneypit/warhost:dev`, commit ("Point the dev template back at the :dev image."), and push `origin/dev`.
6. Report the merge commit and what the push triggers. Do not create a tag locally.

What a `main` push triggers:

- Community Apps reads the template, README, and wording on `main`.
- A change to `Dockerfile`, `entrypoint-unraid.sh`, `webui/`, or `.github/workflows/rebuild-image.yml` also publishes `ghcr.io/suchamoneypit/warhost:latest`, which Unraid offers as a container update. The same paths on `dev` publish `:dev` only.
- `.github/workflows/release.yml` tags the `main` commit: `v0.90` when no version tag exists, otherwise one minor step past the latest tag (`v0.90` then `v0.91`, `v1.00` then `v1.01`). A `VERSION` above the latest tag is used instead. A `VERSION` equal to or below the latest tag is ignored and the latest tag is incremented. A commit that already has a version tag keeps its lowest tag. The tag push does not create another commit.
