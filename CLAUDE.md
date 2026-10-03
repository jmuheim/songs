# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Record decisions in [`decisions/`](decisions/), one file per entry** — see [DECISIONS.md](DECISIONS.md) for the format, and use the `songs-log-decision` skill to add one. Never append to a shared list.

## What this project is

A guitar song book generator. Songs are written in Markdown with inline chord notation. A Ruby script compiles them into an interactive Reveal.js HTML slideshow (`index.html`) and a print-friendly version (`print.html`).

## Working agreements

These are not descriptions of how things happen to work — they are commitments to keep. Follow them without being asked.

- **Ask where new work lands before starting.** Confirm two things up front: which branch its commits go on — a fresh branch off `master` (the default) or the current one — and whether to work in the current checkout or a separate git worktree. Never append unrelated commits to a branch that has already been merged; that mixes two efforts under one PR's history. When in doubt, branch off `master`.
- **Behaviour changes come with tests.** If you change the build pipeline, the chord regex, the multiplex logic, or anything in `style/*.js`, add or update the spec that pins that behaviour before considering the change done — and run `bundle exec rspec`. New behaviour with no covering spec is unfinished work. For the browser specs, follow the `songs-browser-specs` skill.
- **Keep the golden fixtures in sync.** `all-songs.md`, `index.html`, `print.html` and the fixtures under `spec/fixtures/` (except `golden/`) are build outputs — they are generated, not committed (gitignored; the specs regenerate the fixture HTML themselves). The one committed reference is `spec/fixtures/golden/`: when you change the markup or the generator, regenerate it with `bundle exec rake golden:update` in the same change — the golden specs exist to catch exactly the drift you'd otherwise leave behind.
- **One source of truth.** Don't copy logic that already lives in `lib/build_helpers.rb` (or anywhere else) into a second place. If the build and a spec both need a transformation, both call the same helper, so the spec tests what ships.
- **Skills are living artefacts.** The skills in `.claude/skills/` (`tab-to-song`, `songs-browser-specs`, `songs-log-decision`) describe real, current behaviour of this repo. When the song format, the build, or a workflow they document changes, update the matching skill in the same change. If a task reveals a repeatable workflow the skills don't yet cover, propose one.
- **Docs track reality.** This file and `README.md` must match what the code actually does. If you change a command, a dependency, or a default, update both.
- **Knowledge lives in the repo, not in a private store.** Record decisions, conventions, gotchas and working practices here, in [`decisions/`](decisions/), or in `README.md` — never in Claude Code's per-project memory. Repo files travel with the code, are reviewable, and are visible to everyone; a private memory is none of those. If something is worth remembering, commit it.
- **Merging pull requests: wait for green, by hand.** Never `gh pr merge --auto` on this repo. It has no required status checks and repo-level auto-merge is off, so `--auto` has nothing to gate on and merges immediately — even while CI is red or pending (this bit us on #52). Watch the checks (`gh pr checks <n> --watch`, or `gh run watch <id> --exit-status`), then merge once they pass. `master` is deliberately left directly pushable (no branch protection) so a quick fix can go straight in; the "wait for green" is discipline, not a gate. The sibling repo `Access4all/axipedia` is configured the same way.

## Build command

```bash
./build           # Build index.html and print.html
./build --deploy  # HTML + deploy to songs.josh.ch
./dev             # Watch, rebuild, and live-reload on every change (local only, no deploy)
```

Dependencies: Ruby 3.x, Pandoc (`brew install pandoc`), fswatch (`brew install fswatch`), browser-sync (`npm install -g browser-sync`).

The first build on a fresh clone needs local multiplex credentials — `build` refuses to run without them. Create them once with `bundle exec rake multiplex:token` (writes the gitignored `multiplex-token.json`). Deploys to songs.josh.ch happen from CI on every push to `master` once the suite is green (see [Deploy](#deploy)); `./build --deploy` remains the manual fallback.

> **Dev gotcha:** `./dev` passes `--no-ghost-mode` to browser-sync. Ghost mode (on by default) syncs clicks across all open tabs and interferes with the multiplex feature — it makes button presses appear to fire on all "clients" simultaneously during local testing.

## Deploy

Deploying is a CI job (`deploy` in `.github/workflows/test.yml`), not something a local save does. It runs **only on a push to `master`**, and only **after the `rspec` job is green** (`needs: rspec`) — so an untested commit never reaches songs.josh.ch. Its own `concurrency` group serialises deploys. The job generates a fresh multiplex pair, runs `./build`, and `rsync`s `index.html` + `style/` to the server (not `print.html`, matching the old manual deploy).

The server is reached with a dedicated ed25519 **deploy key** (secret `DEPLOY_SSH_KEY`), separate from anyone's personal key and locked on the server via `authorized_keys` to `rrsync` into `…/songs.josh.ch/` only — so the rsync target is relative. The host key is pinned in the workflow (no `StrictHostKeyChecking=no`); refresh it with `ssh-keyscan greip.uberspace.de` if the server ever rotates its key.

`./build --deploy` stays as the manual fallback: it rsyncs the same files from your machine using your own SSH access (absolute path), bypassing CI.

## Song file format

Each song lives in `content/songs/<Title> (<Artist>).md`. Structure:

```markdown
# Song Title (Artist Name)

## About

- Englisch
- Mantra

## Instructions

```
       |E A D G B e|
       |-----------|
A7sus4 |x 0 2 0 3 0|
```

## Section Name

Lyrics with [Chord] inline like this [Am] and here [G7].

## Resources

- [Song](https://youtube.com/...)
```

- **H1** = song title (one per file, shown as the slide title)
- **H2** = section (each becomes a sub-slide)
- **Chords** use `[ChordName]` inline in lyrics
- An **`## About`** section at the top holds the song's tags, one per list item (free text — keep the vocabulary consistent, e.g. `Deutsch` / `Englisch` / `Mundart` / `Pop` / `Rock` / `Mantra`). `song_tags` in `lib/build_helpers.rb` parses it (list items only, so prose in About is ignored); `tag_category` sorts each tag into `Sprache` (the `LANGUAGE_TAGS` list) or `Genre` (everything else) for the [table-of-contents tag filter](#table-of-contents-tag-filter). Tagging is optional.
- An optional **`## Instructions`** section holds alternate chord fingerings (e.g. a capo shape or a barré alternative) as a plain code block, same as the [chord tooltip](#keyboard-and-dialogs)'s guitar tab.
- A **`## Resources`** section lists external links (YouTube, tabs, tutorials).
- `merge_about_section` in `lib/build_helpers.rb` folds `## About`, `## Instructions` and `## Resources` into one `## About` section at the front of the song, at build time — the source file keeps them as separate sections (above) for readability; nothing on disk needs to change when editing a song. The tags become bullets (`- Sprache: Mundart`, `- Genre: Pop`) in the same list as the Resources links; Instructions' code block follows. This merged `## About` is stripped from `print.html` entirely (tags, resource links and alternate fingerings are all screen-only features) — see [`spec/fixtures/golden/about_merged.html`](spec/fixtures/golden/about_merged.html).
- `content/Introduction.md` is always prepended as the first slide

## Chord rendering pipeline

The Ruby script transforms `[Chord]` markers before passing to Pandoc:

```
[C] → `C`{.c}    (CSS class = lowercase first letter)
[Am] → `Am`{.a}
[G7] → `G7`{.g}
```

Pandoc renders these as `<code class="a">Am</code>` etc. CSS in `style/shared.css` assigns a distinct color per chord letter (A=red, B=gray, C=blue, D=green, E=yellow, F=violet, G=brown).

The regex only matches `[Word]` not followed by `(` — so standard Markdown links `[text](url)` are left untouched.

## Shared pipeline

`build` and `spec/support/fixture_builder.rb` run the same code, in `lib/build_helpers.rb`: `songbook_markdown` (front matter with `lang: de-CH`, the introduction, the songs with their chords marked up), `pandoc!`, `post_process_index` and `post_process_print`. What differs is a parameter — `assets:` (`style/` beside `index.html`, `/style/` for the fixtures served from `spec/fixtures/`) and the multiplex config. Change the pipeline there, not in one of its callers.

## Table of contents tag filter

The TOC can be filtered by Sprache (language) and Genre. Each song's tags live in its `## About` section (see [Song file format](#song-file-format)); the build carries them into the TOC and `style/toc-filter.js` wires the interaction:

- `song_tags` parses the `## About` list items of each song; `tag_category` sorts each one into `Sprache` or `Genre`. `build` and `fixture_builder` collect one tag array per song — in the same order the TOC lists them — and pass it to `post_process_index` as `tags:`.
- `inject_toc_filter` (a Nokogiri pass, like `wrap_slide_content`) adds `data-sprache="Englisch"` / `data-genre="Pop"` attributes to each song's TOC `<li>` and prepends a `<fieldset id="toc-filter">` (legend „Filter") holding one `<select>` per category that has at least one tag (each sorted, first option „Alle") and a „Reset" button. The first `<li>` is the Introduction and is skipped — matching is **by order**, not by re-deriving Pandoc's slugs. With no tags anywhere, no fieldset is added.
- `style/toc-filter.js` re-renders on every `change` and hides the `<li>`s that don't match (`.toc-hidden`). The two categories combine with **AND** (a song must match the selected Sprache *and* the selected Genre, for whichever of the two has a selection); „Reset" clears both selects; untagged entries (incl. the Introduction) hide while any filter is active. The selects and the Reset button are real form controls, so the `keyboardCondition` in `body-controls.html` already keeps their keys (Space, arrows, Home/End — reveal.js's own guard only excludes input/textarea, not select) from reaching Reveal. The selection is local to each client and is **not** synced over multiplex.
- Styling: fieldset/select/button layout live in `shared.css`, colours and the sticky bar in `night.css` (with a bright-mode override). The bar is `position: sticky; top: 0`, so it stays visible while the list scrolls underneath it.

The golden `spec/fixtures/golden/toc.html` pins the generated markup; `spec/unit/song_tags_spec.rb` covers the parser, `spec/integration/golden_html_spec.rb` the injected attributes and the print stripping, and `spec/browser/toc_filter_spec.rb` the interaction.

## Output files

These are **generated, not committed** (gitignored; `./build` writes them, CI rebuilds them for the deploy, and the specs rebuild the fixture copies):

- `all-songs.md` — intermediate concatenated Markdown
- `index.html` — interactive night-themed Reveal.js presentation
- `print.html` — serif-themed version for printing. Open it as `print.html?print-pdf` in Chrome and print: reveal.js then lays out every slide as a page of its own

## Tests

```bash
npm install --prefix multiplex-server   # once; needs Node.js >= 18
bundle exec rspec
```

`spec/support/fixture_builder.rb` builds `spec/fixtures/index.html` and `print.html` from the songs in `spec/fixtures/songs/` at the start of the run (they are gitignored, not committed). The browser specs serve them with WEBrick on `127.0.0.1` and a port the OS picks (`spec/support/file_server.rb`), so a second checkout's run does not collide with it.

**The specs never touch the live multiplex channel.** `spec/support/multiplex_server.rb` runs `multiplex-server/` — the official reveal-multiplex package, the same software the public Railway server runs, pinned by commit — on `127.0.0.1:18889` (`localhost.js` keeps it off the LAN) for the whole run. The fixture points at it with a fixed test pair (`sha256(secret) == socketId`, which is all the server checks). Before, the fixture carried `multiplex-token.json`, so the „live sync" spec became master on the channel songs.josh.ch listens to, and moved anyone who had it open at the time. Port and token are fixed rather than fresh per run so that the committed fixture stays the same from run to run. They refuse to start while port 18889 is taken (a multiplex server left over from a manual test, say): their own would die on `EADDRINUSE` while the other one answered the readiness check, and the specs would broadcast into it.

Nothing leaves the machine during a run: the fonts are local too (see below). The slide-zoom expectations are exact values measured with those fonts, so they also catch a font that renders differently. The one exception is the title slide, whose emoji Chrome lays out differently across its own builds: its exact zoom holds locally but is only range-checked on CI (see [emoji zoom is not reproducible across Chrome builds](decisions/2026-09-30-emoji-zoom-is-not-reproducible-across-chrome-builds.md)).

`bundle exec rake golden:update` regenerates the golden snapshots in `spec/fixtures/golden/` after an intended markup change.

**CI runs the whole suite on every push and every pull request** (`.github/workflows/test.yml`): Ruby 3.2, Pandoc pinned to the same 3.9.0.2 the golden fixtures were built with, the `multiplex-server/` dependencies via `npm ci`, then `bundle exec rspec`. `Gemfile.lock` carries `x86_64-linux` alongside `arm64-darwin` so the Linux runner resolves nokogiri's native gem — regenerate both platforms with `bundle lock --add-platform x86_64-linux` if you ever relock.

**Cold-boot retry:** headless Chrome cold-starts on the first browser example of a run, and on a loaded runner that launch handshake used to occasionally exceed `process_timeout` and fail the whole run (and the deploy) with `Ferrum::ProcessTimeoutError: Browser did not produce websocket url …` — not a real assertion, just a flaky launch. A `prepend_before(:each, type: :feature)` hook in `spec/spec_helper.rb` now forces the browser up and, on a boot timeout, quits the dead process and retries the launch (up to three attempts), so a flaky cold start no longer reddens the run. If a `ProcessTimeoutError` still surfaces, the launch failed three times running — treat that as a real environment problem (missing browser, starved runner), not a re-run.

## Vendored reveal.js

`style/revealjs/` holds reveal.js **6.0.2** — only the five files the pages load (`dist/reveal.js`, `reveal.css`, `reset.css`, `theme/night.css`, `theme/serif.css`) plus its `LICENSE`. Everything under `style/` is deployed, so the rest of the release (tests, demo, other themes, `package-lock.json`) stays out. The paths match Pandoc's `revealjs-url`, which is why the `dist/` folder is kept.

To upgrade, copy those five files from `dist/` at the release's tag in the Git repository (`https://raw.githubusercontent.com/hakimel/reveal.js/<tag>/dist/…`), remove the two Google Fonts `@import`s from the start of `theme/night.css` again, rebuild and run the specs. Pandoc's template also loads the notes, search and zoom plugins from their reveal.js 5 paths; the song book uses none of them, and `build` removes those script tags.

6.0.2 is the minimum: it makes every slide but the current one `inert` ([hakimel/reveal.js#1587](https://github.com/hakimel/reveal.js/issues/1587)). With 6.0.1, `Tab` on the Introduction reached the table of contents' links, which reveal.js keeps rendered next door but invisible — 35 of 40 presses landed there.

**Fonts:** `style/fonts/` holds Montserrat 700 and Open Sans (400/700, with italics) as Google Fonts serves them — 25 woff2 files, every subset, with their OFL licenses — and `fonts.css` with Google's `@font-face` rules pointing at them. `post_process_index` links it; the night theme's own `@import`s from fonts.googleapis.com are removed, so no visitor's browser asks Google for anything.

`style/qrcodejs/` holds qrcodejs 1.0.0 (the 🔗 dialog's QR code) with its `LICENSE`, served from the song book itself rather than jsDelivr.

## Slide layout and zoom

Reveal's own `center: true` only centers a slide **among its siblings inside a `.stack`** (`section.stack { flex-direction: column; justify-content: center }` in `shared.css`) — a song or the Introduction, which have sub-slides, gets this for free. `#title-slide` has no sub-slides, so Pandoc never wraps it in a `.stack`, and it needs its own rule (`shared.css`) to center vertically. That rule uses `align-items: center`, not the flex default `stretch`: `style/slide-zoom.js` measures `.slide-content`'s natural (shrink-to-fit) width to decide how far it can zoom in, and a stretched-to-100%-width box always measures as already full, capping the zoom at 1 instead of the ~1.4 the title actually fits.

## Keyboard and dialogs

**The URL is written the moment the page is hidden** (`visibilitychange`): Reveal writes it at most once a second, and iOS stops that timer in the background, so a phone that switched apps right after a slide change and was discarded there reloaded a slide early.


**The overlays are native `<dialog>`s** (in `style/body-controls.html`), opened with `showModal()`: the page behind is inert, Esc closes, and focus returns to the button that opened them. 🚀 is enabled only on a song (a session makes no sense elsewhere) and leads through up to three — the password prompt (focuses its field), then the „wer scrollt?" choice, and on the clients either the guest invitation (guest mode) or a „Es geht gleich los!" announcement of the coming song (self mode); 🔗 shows the QR code. The QR, choice, invite and announcement dialogs focus their title (`tabindex="-1"`, no ring), so a screenreader starts there and a phone shows no keyboard. Two things `showModal()` leaves to us: Reveal listens for keys on the document, where they still arrive from inside a dialog — so each dialog stops `keydown`/`keypress` from propagating, or the arrow keys would page the deck behind it and Esc would open Reveal's overview — and a click on the backdrop lands on the `<dialog>` itself, which closes it.

**Space on a focused button presses that button, and only that** (`keyboardCondition`, set with `Reveal.configure` on load): Reveal used to turn the page as well, so Space after 🌞 switched the theme back and moved on. The exception is a focus nobody can see: a mouse click leaves the button focused without a ring, and there Space blurs it and turns the page, as the one clicking expects. Whether the ring shows is read on `focusin`, because Chrome turns `:focus-visible` on as soon as any key is pressed.

**The buttons' labels are their tooltips.** Each control's `.visually-hidden` text is shown as a tooltip on hover (only where there is hover, `(hover: hover)`, so a tap on a phone shows nothing) and on keyboard focus. Esc hides it without opening Reveal's overview, any other key hides it too, and it stays hidden until the pointer leaves or the focus moves.

**Chords are buttons** (`style/chords.js`): `role="button"`, `tabindex="0"`, `aria-expanded`; Enter or Space opens the fingering, the tooltip is read out as it appears (`aria-live`). The key handler sits on `window`, so it runs after Reveal's and skips a key Reveal acted on — Space on a chord focused by a mouse click turns the page, like on any button (see above). The tooltip shows the guitar tab (`|E A D G B e|`, preferring a song's own Instructions legend over the built-in `DEFAULT_CHORDS` fallback) beside a ukulele tab (`|G C E A|`, standard re-entrant tuning) from the separate `UKULELE_CHORDS` dictionary — side by side rather than stacked, since a slide has more spare width than height. The chord name only appears once, on the guitar column's own `Name |…|` row; the ukulele column (no per-song override — songs never document their own ukulele voicing) is just `|…|`, and a chord missing from `UKULELE_CHORDS` falls back to a single guitar-only column.

**Storage is optional:** with site data blocked, touching `localStorage` or `sessionStorage` throws, so every access is wrapped; the theme then switches without being remembered.

## Multiplex (live sync)

The presentation uses the [Reveal.js multiplex plugin](https://revealjs.com/multiplex/) via `multiplex.up.railway.app` so that the audience can follow along on their own devices. It is not a running mirror of the presenter's every move: the presenter opens a **live-scroll session** on one song, and either scrolls it or hands the scrolling to a guest for that song.

The code is the second `<script>` in `style/body-controls.html`; the server is a pure relay (one event, `multiplex-statechanged`, forwarded to everyone but the sender when `sha256(secret) == socketId`, no storage). Three message types ride on that one event: `session` (from the presenter), `state` (from whoever scrolls) and `volunteer` (from a guest offering). `body-controls.html` is spliced in *after* the build's `keyboard:`/`controls:` rewrites (see `post_process_index`), so its own `Reveal.configure` calls are not mistaken for Pandoc's init.

- **The presenter is the single authority.** 🚀 (top right, enabled only while the current slide is a song) asks for the password once per tab (`sessionStorage` `multiplex-presenter` holds the claim and the live session), then opens a choice: „Ich selber möchte scrollen" or „Ein Gast soll scrollen". The role and session survive a reload. Only the presenter opens a session, names the scroller and closes it; 🚀 then reads „Live-Scrollen beenden" (and stays enabled, so it can be ended). Another presenter with a higher `claim` (a duplicated tab settles by `from`) makes this one step down — the only leaderless bit left.
- **Guest delegation.** In guest mode every client is asked „«Song» wird als nächstes gespielt. Möchtest du das Live-Scrollen übernehmen?". The first „Ja" the presenter hears wins — it echoes the chosen `scrollerId`, the other invites close, and everyone (the presenter included) follows the guest. A single authority means two near-simultaneous „Ja"s cannot both take over.
- **Self-scroll announcement.** In self mode the presenter scrolls, so there is nothing to volunteer for; each client that is present as the session opens is shown „Der nächste Song ist «Song». Es geht gleich los!" with an OK button (once per session, `announcedFor`) and then follows along. The opening `session` carries `fresh: true` and the heartbeats do not, so a latecomer who only ever hears a heartbeat just follows — as with the guest invite. The presenter sees no such dialog.
- **The scroller is locked to its song** (`SCROLLER_KEYS` disables the horizontal keys plus Space/Home/End — reveal.js binds those to "next slide"/"first slide"/"last slide", which reached the snap-back below too, but only after already jumping and losing the scroll position (v reset to 0); a capture-phase guard swallows horizontal *swipes* before Reveal sees them — Reveal has no vertical-only touch option, so this keeps vertical scrolling while a left/right swipe does nothing; a link that still leaves the song snaps back on `slidechanged`). It may only scroll up/down within the current song; to move on, the presenter ends the session.
- **Everyone else follows, with no opt-out.** A follower's keyboard, touch and controls are off and its view is snapped to the scroller — there is no more „browse freely" (👣 is gone). A follower that hears nothing from the session for three heartbeats frees itself rather than freeze; the presenter's next heartbeat locks it again.
- **Heartbeat:** the presenter repeats the `session` and the scroller its `state` every 2 s (`HEARTBEAT_MS`; the specs shorten it through `window.MULTIPLEX.heartbeat`), and again right after a reconnect. That is how someone who opens the page mid-session, or comes back from a dead spot, catches up — the relay hands out no last state. A latecomer who arrives while a guest is still being sought is invited too; once a scroller is named, latecomers just follow.
- **Only the slide is sent** (`stateToSend`): indices, never `overview` or `paused`. While the scroller browses the overview, the slide it was opened on is repeated.
- **Ending the session** drops everyone — the presenter included — back onto the table of contents (`gotoToc`, the `#TOC` slide) and shows a toast (`#multiplex-toast`, `aria-live`): „Du kannst jetzt wieder frei navigieren" to everyone who was in it, and „Vielen Dank fürs Scrollen!" on top of that for the guest who scrolled. A silent timeout (lost connection) frees a follower where it stands, without the jump.
- **Status line** (`#multiplex-status`, `role="status"`, under the top-right buttons): „Du scrollst live" / „Warte auf Gast …" / „Gast scrollt" for the presenter, „Du scrollst für alle" for the guest, „Folgt" for a follower, „Keine Verbindung" for a dropped connection, and empty when no session runs.
- **QR code** (🔗, top right): shows a QR code of the current URL so new people can join.

See [decisions/2026-09-30-live-scroll-sessions-presenter-delegates-to-a-guest.md](decisions/2026-09-30-live-scroll-sessions-presenter-delegates-to-a-guest.md).

### Token

The `socketId` / `secret` pair is generated offline, never fetched: the relay only checks `sha256(secret) == socketId`, so any self-consistent pair works. `build` resolves it in this order, and **refuses to build if none is found** (no silent network fetch):

1. `MULTIPLEX_SOCKET_ID` + `MULTIPLEX_SECRET` from the environment — the CI deploy generates a fresh pair per run this way.
2. a gitignored `multiplex-token.json` for local builds — create it once with `bundle exec rake multiplex:token` (run it again for a fresh local session).

The file is no longer committed, so a local build never shares songs.josh.ch's live channel. The generator is `BuildHelpers.generate_multiplex_token`.

### Password

Default password: `guitar`. Override with the `MASTER_PASSWORD` env var at build time:

```bash
MASTER_PASSWORD=mypassword ./build
```

The password is embedded in the generated HTML (visible in source). This is intentional — the goal is only to keep the audience from accidentally starting a live-scroll session, not real security.

## Legacy songs

`content/legacy-songs/` holds songs removed from the active set. They are not included in the build.
