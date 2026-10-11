# /unraid-script

Print four separate Unraid web-terminal scripts: a download for `main`, a download for `dev`, a download for `webui`, and a clean-slate removal. Never combine the downloads into one paste.

1. Run these and keep each stdout separate:
   - `sh scripts/print_template_fetch.sh --branch main`
   - `sh scripts/print_template_fetch.sh --branch dev`
   - `sh scripts/print_template_fetch.sh --branch webui`
   - `sh scripts/print_template_fetch.sh --clean --branch main --branch dev --branch webui`
   If the message after this command asks for the Apps tab route, add `--private` to the three download commands only. Do not add `--private` to the clean command.
2. Reply with four shell blocks, labeled main, dev, webui, and clean-slate. Each block is only that command's stdout.
3. Then three sentences. Paste only the branch you are about to add, into the Unraid web terminal (the `>_` icon). For a user template, the **Template** dropdown label is the saved filename with a leading `my-` removed; for the Apps tab, the files show under **Apps → Private** and are not Template dropdown labels. The clean-slate script stops and removes containers named `<Name>`, `<Name>-dev`, and `<Name>-webui`, drops those names from `/var/lib/docker/unraid-autostart`, removes the template image only when no container is still using it, and deletes those three user-template files plus the three private-template files. It also removes `/mnt/user/appdata/warno/<port>/settings` for those containers, which holds the login and key. A folder still mounted by another container is left in place. On Apply, Unraid writes `my-<Name>.xml` from the Name field.
4. Do not retype the URLs, filenames, image, or container names, and do not merge the blocks.
