# /unraid-template-installscript

Print the Unraid web-terminal command that downloads this container template onto the flash drive, for use until Community Applications lists it.

1. Run `sh scripts/print_template_fetch.sh`. If the message after this command asks for the Apps tab route, run `sh scripts/print_template_fetch.sh --private` instead.
2. Reply with that stdout in one shell block. Then one sentence: paste it into the Unraid web terminal (the `>_` icon). For the default command, the **Template** dropdown label is the saved filename with a leading `my-` removed, so it matches `<Name>` including capitals.
3. If an older copy in `templates-user` uses the repository template filename instead of `my-<Name>.xml`, say to remove that file so the dropdown does not keep a second entry.
4. Do not retype the URL or the filename, and do not add a second copy of the command.
