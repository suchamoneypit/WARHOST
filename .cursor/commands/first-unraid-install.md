# /first-unraid-install

Guide and audit my first installation of this WARNO container on Unraid 7.x. Follow `docs/INSTALL-UNRAID.md`; do not invent steps, field values, or scenario IDs.

1. Check the published state first and report each item as checked or failed: the raw template URL in `templates/warhost.xml` `<TemplateURL>` returns 200; the `ghcr.io/suchamoneypit/warhost:latest` manifest is readable with an anonymous token; the latest **Rebuild WARHOST image** workflow run on GitHub succeeded.
2. Walk the prerequisites checklist in `docs/INSTALL-UNRAID.md`. Ask me only for the items I must supply: whether Eugen's reply with login and key has arrived, my public WAN IP, whether the router forward is done, and which scenario ID I want. Never ask me to paste the key or login into chat.
3. Give the Unraid steps in order with the exact field values from the template defaults, and for each step the log line or file that shows it worked. For the template download, run `sh scripts/print_template_fetch.sh` and give that stdout as the Unraid terminal command (the same output as `/unraid-template-installscript`). Use `--private` only when the Apps tab route was asked for. Do not invent a different URL or path. The User templates label is the flash filename with `my-` removed. If `warno-dedicated-server.xml` or `my-WARNO-Dedicated-Server.xml` is still in that folder, say to delete it.
4. If I report an error or paste a log, use the troubleshooting table in `docs/INSTALL-UNRAID.md` first. Keep "container started" separate from "players can join from the internet".
5. If a step is blocked by something only I can do, say so plainly and stop there.
6. When the install succeeds, remind me to record the result in `docs/ROADMAP.md` (goal 1) and to compare Unraid's saved copy of the template under `/boot/config/plugins/dockerMan/templates-user/` with `templates/warhost.xml`.
