# Unraid game-server template guide (generic)

Reusable guidance for publishing a Docker container template for Unraid. Nothing here is specific to WARNO; the game-specific facts for this repository live in `README.md`, `docs/INSTALL-UNRAID.md`, and `docs/ARCHITECTURE.md`. When this is copied into a template repository for another game, only the "Reuse checklist" at the end should need editing.

Sources checked on 2026-10-09:

- Unraid docs, [Managing & customizing containers](https://docs.unraid.net/unraid-os/manual/docker-management/)
- Unraid forum, [Docker template XML schema](https://forums.unraid.net/topic/38619-docker-template-xml-schema/) (maintained by the Community Applications author)
- Unraid forum, [Template Repositories removed in 6.10](https://forums.unraid.net/topic/112170-allow-template-repositories-to-be-hosted-from-other-sources/)
- Unraid webgui, [CreateDocker.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/CreateDocker.php) (the Template dropdown label is the filename with `my-` removed) and [DockerClient.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/DockerClient.php) `getUserTemplatePath` (Unraid saves `my-<Name>.xml` and keeps that case). Read from `master` on 2026-10-09.

## Repository shape

| Path | Purpose |
| --- | --- |
| `templates/<app>.xml` | The Unraid container template. One file per container type. |
| `ca_profile.xml` | Community Applications repository profile: `Profile`, `Icon`, `WebPage`, `Forum`. |
| `icon.png` | Icon referenced by raw GitHub URL from the template and profile. |
| `Dockerfile`, `entrypoint-*.sh` | Optional wrapper image when the upstream image needs settings files generated from form fields. Prefer wrapping the official image over copying its launch logic. |
| `samples/` | Placeholder copies of generated files. Never real credentials. |
| `tests/` | Wrapper tests that run against a fake upstream entrypoint, never the real game server. |
| `scripts/check_repo.sh` | Local invariants: XML well-formed, required tags, the dedicated key shown in clear text, placeholder scan, shell syntax. |
| `scripts/print_template_fetch.sh` | Prints the Unraid terminal command that downloads the template from `<TemplateURL>` before Community Applications lists it. |
| `.github/workflows/` | Run the checks on push and PR. Optionally rebuild the wrapper image when upstream changes. |

## Template XML

- Use `<Container version="2">`. Express every path, variable, and port as a one-line `<Config>` element. Unraid 6.10+ no longer writes the legacy `<Networking>`, `<Data>`, and `<Environment>` blocks; leave them out.
- `<Config>` attributes: `Name` (label), `Target` (container path, variable name, or container port), `Default`, `Mode` (`rw`/`ro` for paths, `tcp`/`udp` for ports), `Description`, `Type` (`Path`, `Variable`, `Port`, `Device`, `Label`), `Display` (`always` or `advanced`), `Required`, `Mask`. Put the default in both `Default="..."` and the element text.
- Set `Mask="true"` on every secret. Give secrets an empty default so a fresh install never ships a placeholder into a live server. On this form, Eugen Login and Eugen Dedicated Key stay `Mask="false"`. The Docker edit page is an admin screen, and the key must stay readable so servers can be told apart. The startup log still names only the last four characters of the key.
- `Display="advanced"` hides fields behind Unraid's **Show more settings** toggle. Put the fields a first-time user must fill under `always` and tuning values under `advanced`.
- `<Overview>` is what the Apps tab and the Add Container page show. Community Applications ignores `<Description>` when `<Overview>` exists, so if both are present keep them in agreement.
- `<Requires>` is a free-text line for things the user must obtain outside Unraid (accounts, keys, client-side mods).
- `<TemplateURL>` must be the raw GitHub URL of this exact file. `<Icon>` and the profile icon must be raw URLs too. `<Support>` and `<Project>` are shown in the container context menu.
- `<Category>` uses CA's list, for example `GameServers:`.
- Escape `&` as `&amp;` everywhere, including descriptions. An unescaped ampersand makes CA drop the template and dockerMan refuse the install.
- CA only guarantees the formatting dockerMan writes when you press **Save** on the Add Container page. After the first real install, compare the copy Unraid saved under `/boot/config/plugins/dockerMan/templates-user/` with the repository file and prefer dockerMan's formatting.

## Networking

Pick one and document it in the Overview, the README, and the port field descriptions.

- **Bridge** (Unraid default). Add a `Type="Port"` Config per protocol. Players reach the host port; Docker maps it to the container port. Two instances can map different host ports to the same container port.
- **Host**. The container shares Unraid's network stack. Do not add `Type="Port"` entries; Unraid shows no port mapping, and the game's own listen-port setting decides the port. The port must be free on the Unraid host itself, and every extra instance needs a different port. Use host only when the upstream vendor asks for it or the game needs it.
- **Custom (macvlan/ipvlan)** gives the container its own LAN IP. It avoids host port conflicts but adds network setup for the user. Not recommended as a template default.

Whatever the mode, the README must state the exact ports and protocols to forward on the router, and that forwarding goes to the Unraid server's LAN IP. Say separately whether the server needs outbound access to a vendor master server or auth service, because a container can start cleanly and still be invisible to players.

## Paths

- Use `/mnt/user/appdata/<app>/...` as the host default. Unraid creates the host path on first start if it is missing.
- One host folder per instance. Document which generated files land there and which of them contain secrets.
- The container path must match what the upstream image reads.

## Secrets

- Secrets live in the Unraid form (and whatever file the wrapper writes on the server). They never go in git, examples, screenshots, issues, or chat.
- Use obvious placeholders such as `YOUR_<APP>_KEY_HERE` in samples, and have the wrapper refuse `YOUR_*`-style placeholders at start.
- `.gitignore` the generated credential file and any local `settings/` or `appdata/` folder. Add a scan to `scripts/check_repo.sh` that fails if a tracked file contains a non-placeholder credential.
- A secret that reaches git history is compromised even after a later delete. Rotate it.

## Getting a template into Unraid before it is in Community Applications

Unraid 6.10 removed the **Template Repositories** URL field from the Docker tab. There is no "paste a template URL" step in Unraid 7.x. Two supported routes remain:

1. **User templates.** From the Unraid terminal (or via the flash share), save the XML to `/boot/config/plugins/dockerMan/templates-user/my-<Name>.xml`, using the `<Name>` text as written, including capitals. Then **Docker → Add Container**, open the **Template** dropdown, and pick it under **User templates**. The dropdown label is that filename with `my-` removed, not the `<Name>` element. Every field prefills from the XML. Saving under the repository filename instead, for example `app.xml`, shows that filename in the dropdown.
2. **Private CA repository.** Save the XML to `/boot/config/plugins/community.applications/private/<anyFolderName>/<app>.xml`. It then appears in the **Apps** tab under **Private** (or its own category) and installs like any CA app.

Route 1 is the simplest for a one-off test. Route 2 behaves like the eventual CA listing. Both read the file from the flash drive, so the XML must be downloaded first; the raw GitHub URL is for that download, not for Unraid to fetch.

`scripts/print_template_fetch.sh` reads `<TemplateURL>` and `<Name>` from the single file in `templates/` (or from a path argument) and prints that download. With no arguments the destination is `templates-user/my-<Name>.xml`. `--private` uses `community.applications/private/<owner>/` and the repository filename, taking `<owner>` from a `raw.githubusercontent.com` URL. stdout is only the command, so it can be pasted into the Unraid web terminal. `/unraid-template-installscript` runs this script and shows that stdout; it does not keep a second copy of the URL. The install docs must contain that output, and `scripts/check_repo.sh` must fail when they disagree.

## Multiple instances

Add a second container from the same template and change the container name, the port, and the host path. Do not use Unraid's **Reinstall** action for a second instance; that replaces the existing container.

## Publishing the image

- Unraid pulls anonymously. A private GHCR package fails with a pull error on **Create**. Set the package visibility to **Public** in the package settings and confirm it with an anonymous manifest read, for example:

  ```sh
  TOKEN=$(curl -s "https://ghcr.io/token?scope=repository:OWNER/IMAGE:pull" | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
  curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.index.v1+json" \
    https://ghcr.io/v2/OWNER/IMAGE/manifests/latest
  ```

  `200` means the image is publicly pullable.
- If the image wraps an upstream image, record the upstream digest in a label so a scheduled workflow can skip rebuilds when nothing changed.

## Levels of verification

Say which level a claim reached. They are not interchangeable.

| Level | What it shows | How |
| --- | --- | --- |
| Local | XML is well-formed and repository invariants hold; the wrapper writes the right files | `sh scripts/check_repo.sh` |
| Image | The published image exists, is public, and has the expected entrypoint | Anonymous registry read (see above) |
| Unraid | The container is created from the template, starts, and the logs show the expected startup lines | A real Unraid install, then **Logs** on the container |
| Remote | A player outside the LAN can see and join the server | Someone on another network connects |

A passing local check says nothing about Unraid behavior. A container that stays up says nothing about remote connectivity.

## Community Applications submission

Submit at [https://ca.unraid.net/submit](https://ca.unraid.net/submit) after at least one install has reached the Unraid level above. `ca_profile.xml` must have non-empty `Profile`, `Icon`, `WebPage`, and `Forum` (a GitHub issues URL is acceptable for `Forum`).

## Reuse checklist

When copying this layout for another game server:

1. Rename the template file, container `<Name>`, `<Repository>`, `<Registry>`, `<TemplateURL>`, `<Icon>`, `<Support>`, `<Project>`, and the paths in `ca_profile.xml`.
2. Replace every form field with the new game's variables; keep secrets masked and empty by default, except a value the operator must read on an admin-only edit page, as with the Eugen login and dedicated key.
3. Decide bridge vs host and update the Overview, README, and port descriptions together.
4. Rewrite the wrapper entrypoint and `tests/` for the new settings files, and update the expected-file assertions.
5. Update `scripts/check_repo.sh` for the new secret variable names and settings path.
6. Replace the game-specific docs (`README.md`, `docs/INSTALL-UNRAID.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/ROADMAP.md`) and the game-specific Cursor rule, researcher agent, and credential reviewer. The generic rule, docs-consistency agent, template reviewer, verifier, the other commands, this guide, and `scripts/print_template_fetch.sh` carry over.
