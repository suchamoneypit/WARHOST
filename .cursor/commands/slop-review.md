# /slop-review

Adversarial review of what this repository ships, read the way skeptical people read a project before they install it or list it. Report only. Do not modify files.

The project says openly that AI tools built it. That is not a defect. Do not recommend hiding the disclosure; judge how it reads. The question is whether the shipped surface reads as deliberate, reviewed work or as unreviewed AI output, so the test for every line is "would a careful human maintainer ship this?", not "could an AI have written it?". Lines the maintainer wrote by hand get the same treatment, because a reader cannot tell who wrote what. Be direct: no praise outside the Keep list, no generic advice such as "improve clarity", no hedging.

## Ground rules

- Do the review in this chat. Until the report is written, do not launch this repository's subagents, and do not open `.cursor/plans/` or past chat transcripts. They carry the authoring assumptions under audit.
- If this chat already holds earlier work on this repository, say so in the first line of the report. The review is meant to start without that context.
- Read-only. You may run `git`, `rg`, `sh -n`, the repository check script, and local scripts that have no side effects. Do not edit, stage, commit, or push.
- Review the working tree of the current branch. Run `git status --short` and `git diff --stat origin/main...HEAD`, and note what differs from `main`, which is what visitors and Community Applications see today.
- Fetch an upstream page only when a finding depends on an upstream fact the repository does not cite. Label other upstream claims unverified.
- Do not stop to ask questions. Put them in the report as "needs maintainer input".
- Never print a real login, key, or credential file.

## Readers

Every finding names the reader who reacts:

1. **Moderator**: a Community Applications moderator deciding whether to list the app. Sees the name, icon, category, Overview, and Requires, then skims the template.
2. **Installer**: a first-time Unraid user filling in the Add Container form and following the install guide.
3. **Auditor**: a security-minded homelabber who reads the Dockerfile, the entrypoint, and how the image is published before handing over a credential.
4. **Player-host**: someone who runs servers for this game and knows its maps, mods, lobby sizes, and modes.
5. **Editor**: a technical editor who has read many AI-written READMEs and notices voice, repetition, and leftover process notes.

## Scope

- **Tier 1, the product, every line.** The files listed under Project specifics: the template, the Community Applications profile, the icon, the README, the install guide, the Dockerfile, the entrypoint (as code a stranger must trust, and as every string it prints), the samples, and the license.
- **Tier 2, docs the README links to, skimmed.** The other files in `docs/`. Flag only facts that are stale or contradict tier 1, and anything that would embarrass a visitor who clicks through. At most 10 findings.
- **Tier 3, supporting tools, where mess is acceptable.** `scripts/`, `tests/`, `.github/workflows/`, `.cursor/`, version files, and dotfiles. Flag only what is broken, leaks a secret, contradicts tier 1, or is shown to users. No style notes. Read the image-publishing workflow only to answer what ends up in the image users pull.
- **Untracked files** in shipped folders: name any that would look careless if committed.

## What counts as slop

Tag each finding with one category:

- **RESIDUE**: process or audit trail in user-facing text. Dated "read on" or "checked on" stamps, test-run narratives, rename history, commit references, notes on what the repository has or has not observed, superseded states.
- **REPEAT**: a fact restated across sections or files beyond what navigation needs. Verbatim duplicate sentences. Restated arithmetic.
- **HEDGE**: caveats that do not change what the reader does, above all on the main path.
- **CONTRA**: two surfaces disagree: template, Overview, README, install guide, log messages, samples, or docs.
- **WRONG**: a factual error, a broken command or link, a typo, wrong casing, or an inconsistent date format.
- **ROBOT**: mechanical voice. Chains of short declaratives that each restate the last, tautologies, a field name restated as its own definition, "see the README" where one sentence would answer. Or the opposite: marketing filler.
- **AUDIENCE**: content for the wrong reader. License, moderation, or maintainer notes on the app card or in a field description; implementation detail in an error message; agent or editor tooling in user install steps.
- **FILLER**: a sentence that informs no reader's decision, including non sequiturs.
- **STRUCTURE**: decorative tables, bold, or headers around one-sentence content; walls of edge cases on the main path; a main path that is hard to find.
- **OVERBUILT**: code complexity out of proportion to the risk, or complexity the docs then have to explain. Hard-coded special cases and dated literals in runtime code. Comments that narrate instead of stating a constraint.
- **ASSET**: icon problems: generation artifacts, edge or crop defects, detail that is lost at small sizes, imagery a reader might object to.

Not slop, so do not flag: the AI disclosure itself; one short "not yet verified" list at the end of a guide; sources cited in architecture or decision docs; superseded entries kept in a decision log; the settled decisions under Project specifics. For those, critique how they are explained, not the choice.

## Passes

Work in this order. Draft passes 1 to 5 before you open tier 2, so first impressions are not shaped by the maintainers' reasoning.

1. **App card** (Moderator). Write the card out as text: name, category, the Overview as Unraid renders it, and Requires. View the icon at full size. If you can make a copy about 64 pixels wide outside the repository, view that too; otherwise judge what survives at that size. End with the moderator's verdict in three sentences: list it, or ask for what?
2. **Form** (Installer). Rebuild the Add Container form from the template, top to bottom: each label, its prefilled value, the description printed under the input, and which fields sit behind Show more settings. Show it as a text mock. For each field, ask whether a newcomer can fill it in correctly after one read. Flag notes to self, descriptions that only point elsewhere, and descriptions that repeat the default.
3. **Landing page** (Editor, Installer). The README's first screen, from the title to the first section heading: does it say what this is, who it is for, and how to start, without errors? Then the whole README. It is also the template's ReadMe, so judge it in that role too. If you can open a browser, view the rendered file on GitHub for the current branch.
4. **Install walk-through** (Installer). Follow the install guide as if executing it. Mark each place a newcomer would stall, doubt a step, or read it twice. Check that every command pastes and runs as written.
5. **Code** (Auditor, Editor). Read the Dockerfile and the entrypoint in full. Check correctness and the behavior the docs promise. Judge proportionality: what would a senior reviewer cut, and what would they keep? Check naming, comments, special cases, and dated literals. List every message the entrypoint prints or exits with, and grade each one: does it say what is wrong and the one action that fixes it, in plain words?
6. **Consistency matrix.** For each fact listed under Project specifics, give its value on every surface that states it. Each mismatch is a CONTRA finding.
7. **Tier 2 skim and tier 3 sanity check**, within the limits above. Run the repository check script once, and run any local script a publish depends on if it has no side effects.
8. **Self-check before you answer.**
   - Every finding quotes the exact text, cites a `file:line` you re-read in this run, names a reader and a category, and gives a drop-in replacement or "delete".
   - Repeated instances of one pattern are one finding that lists every location.
   - Taste-only notes are dropped or marked S3.
   - A replacement that needs a fact the repository does not have says "needs maintainer input". Do not invent facts, versions, or test results.
   - Read your report as the Editor would, and cut its padding, hedges, and generic advice.

## Severity

- **S1, credibility breaker**: an auditor stops trusting the rest. A contradiction about what the product does, a wrong fact, a broken command, or a typo or shouting on the card or the first screen.
- **S2, slop tell**: an experienced reader would quote it in a critical forum post as unreviewed AI output.
- **S3, polish**: it costs readability, and most readers would not notice.

Be exhaustive at S1 and S2. Include S3 when the fix is cheap.

## Replacement text

Plain and specific, second person for instructions. Each fact has one home, and other places link to it. A field description says what to enter and why in at most two short sentences. An error message says what is wrong and the one action that fixes it. Every replacement keeps the repository check passing and leaves the protected values under Project specifics alone. If the best fix would break a check or change a protected value, say so and file it under Decisions to revisit.

## Report

One Markdown answer. The first line names the branch, the commit (`git rev-parse --short HEAD`), and your model, if you know it. Then, in this order:

1. **Verdict**, under 150 words: would these readers see quality work? Score each surface from 1 to 5: card, form, README, install guide, code, icon. 5 means a careful human maintainer would ship it as is; 1 means obvious unreviewed output. One line of reasoning per score.
2. **Top 10 fixes**, ranked by impact on readers per minute of effort, each pointing to a finding ID.
3. **Findings**, grouped by surface, with IDs `CARD-n`, `FORM-n`, `README-n`, `INSTALL-n`, `CODE-n`, `ICON-n`, `DOCS-n` (tier 2), and `TOOLS-n` (tier 3). Each one: `ID · S1|S2|S3 · CATEGORY · reader`, then `file:line`, the quoted text, one sentence on how that reader reacts, and the replacement.
4. **Repetition ledger**: every fact stated three or more times, with all locations and the one place it should live.
5. **Consistency matrix**: facts by surface, mismatches marked.
6. **Full rewrites**: the template Overview; every Config Description, with its character count; Requires; the profile text; the README first screen; and every entrypoint message graded below acceptable.
7. **Decisions to revisit**: settled decisions or protected values these readers would push back on, with the trade-off. These are not fixes.
8. **Keep list**: what already reads as quality work and must survive the fixes.
9. **Tier 2 and tier 3 notes.**
10. **Not checked**: what needs a running server, the Community Applications scan, real credentials, or a browser you did not have.

Stop after the report. If I reply `apply` with finding IDs, apply only those, using the apply flow under Project specifics. Do not commit.

## Project specifics (WARHOST)

Replace this section when copying the command to another repository.

- **Branches.** Day-to-day work is on `dev`. `main` is the published snapshot that GitHub visitors and Community Applications read.
- **Tier 1 files.** `templates/warhost.xml`, `ca_profile.xml`, `icon.png`, `README.md` (the GitHub landing page and the template's `<ReadMe>`), `docs/INSTALL-UNRAID.md`, `Dockerfile`, `entrypoint-unraid.sh`, `samples/`, `LICENSE`. The image-publishing workflow is `.github/workflows/rebuild-image.yml`.
- **The game.** WARNO, by Eugen Systems. The image is built `FROM eugensystems/warno`, Eugen's official dedicated-server image.
- **Check script.** `sh scripts/check_repo.sh`. It fails when a `<Config>` spans more than one line, when a Config Description is longer than 240 characters or contains a `br` tag, when `<Overview>` or `<Description>` is empty, or when the XML does not parse, which a bare `&` outside a CDATA section causes. Write `&amp;` everywhere anyway: `docs/UNRAID-TEMPLATE-GUIDE.md` says Community Applications drops a template with a bare `&`. It also fails when `README.md` or `docs/INSTALL-UNRAID.md` lacks the exact command block printed by `sh scripts/print_template_fetch.sh`, when the install guide lacks the `--private` block, or when the README does not name `scripts/print_template_fetch.sh`. It pins the `<ReadMe>` and `<License>` URLs, host networking, `Mask="false"` on the dedicated key, and the unlabeled image license.
- **Protected values**, from `.cursor/rules/warno-project.mdc`: Game Port default `10400`, Map `RDPort_JungleLaw_2v2_CONQ`, Workshop Mod List `3811913066/15`, host networking, container path `/server/settings`, host folder `/mnt/user/appdata/warno/10400/settings`, image `ghcr.io/suchamoneypit/warhost:latest`, the image build logic, the fixed `variables.ini` values, and Eugen's launch arguments.
- **Settled decisions**, from `docs/DECISIONS.md`:
  - Host networking with no port mapping. The operator forwards the game port as TCP and UDP.
  - Eugen Login and Eugen Dedicated Key are clear text on the form, because the Docker edit page is an admin screen. The startup log names only the last 4 characters of the key. Do not recommend masking either field.
  - One container per server. Each added server uses the previous Game Port plus 1, a settings folder named for its port, and its own Server Name.
  - Write Config From Form defaults to `true` and rewrites `login.ini`, `variables.ini`, and `params_for_ai.json` on every start.
  - The wrapper writes settings and then runs Eugen's entrypoint. It does not copy Eugen's launch arguments.
  - Scenario-ID and mod catalogs live in the README, not on the form. Map is on the main form, under Server Name.
  - The image tracks `eugensystems/warno:latest` and is rebuilt when Eugen publishes.
  - `LICENSE` (MIT) covers the repository files. The image license is left unlabeled.
- **How Unraid shows the template**, as recorded in `docs/ARCHITECTURE.md` from [CreateDocker.php](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/CreateDocker.php): each Config Description is printed under its input, and `Display="advanced"` fields sit behind Show more settings. In the Overview, `[` and `]` become tags, `<br>` becomes a newline, tags are stripped, and the basic view turns newlines into line breaks; that has not been checked on a server. Moderators review from `<Name>` and `<Overview>` ([repository XML help](https://ca.unraid.net/submit/help/repository-xml)). Community Applications ignores `<Description>` when `<Overview>` is present ([template schema thread](https://forums.unraid.net/topic/38619-docker-template-xml-schema/)).
- **Facts for the consistency matrix**: lobby size (Max Players, Minimum Players, Team Size, and any size named in Server Name or prose), Map, Workshop Mod List, Workshop Mod Tags, Combat Rule, Game Port and the plus-1 rule, settings folder, image, servers per login and key pair, network mode and protocols, Write Config From Form behavior, the files the wrapper writes, and Community Applications status.
- **Strings users see** are in three places: the template's attributes and text, the Markdown, and every `printf` and `die` in `entrypoint-unraid.sh`.
- **Credentials.** The only placeholders allowed in git are `YOUR_EUGEN_LOGIN_HERE` and `YOUR_EUGEN_DEDICATED_KEY_HERE`.
- **Apply flow.** For each changed user-facing fact, launch `docs-consistency` and apply only the sentences it names. Run `sh scripts/check_repo.sh`. Then launch `unraid-template-reviewer` and `verifier` in parallel.
