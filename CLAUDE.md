# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Record decisions in [`decisions/`](decisions/), one file per entry** — see [DECISIONS.md](DECISIONS.md) for the format. Never append to a shared list.

## What this project is

A guitar song book generator. Songs are written in Markdown with inline chord notation. A Ruby script compiles them into an interactive Reveal.js HTML slideshow (`index.html`) and a print-friendly version (`print.html`).

## Working agreements

These are not descriptions of how things happen to work — they are commitments to keep. Follow them without being asked.

- **Ask where new work lands before starting.** Confirm two things up front: which branch its commits go on — a fresh branch off `master` (the default) or the current one — and whether to work in the current checkout or a separate git worktree. Never append unrelated commits to a branch that has already been merged; that mixes two efforts under one PR's history. When in doubt, branch off `master`.
- **Behaviour changes come with tests.** If you change the build pipeline, the chord regex, the multiplex logic, or anything in `style/*.js`, add or update the spec that pins that behaviour before considering the change done — and run `bundle exec rspec`. New behaviour with no covering spec is unfinished work.
- **Keep the golden fixtures in sync.** `all-songs.md`, `index.html`, `print.html` and the fixtures under `spec/fixtures/` (except `golden/`) are build outputs — they are generated, not committed (gitignored; the specs regenerate the fixture HTML themselves). The one committed reference is `spec/fixtures/golden/`: when you change the markup or the generator, regenerate it with `bundle exec rake golden:update` in the same change — the golden specs exist to catch exactly the drift you'd otherwise leave behind.
- **One source of truth.** Don't copy logic that already lives in `lib/build_helpers.rb` (or anywhere else) into a second place. If the build and a spec both need a transformation, both call the same helper, so the spec tests what ships.
- **Skills are living artefacts.** The skills in `.claude/skills/` (e.g. `tab-to-song`) describe real, current behaviour of this repo. When the song format, the build, or a workflow they document changes, update the matching skill in the same change. If a task reveals a repeatable workflow the skills don't yet cover, propose one.
- **Docs track reality.** This file and `README.md` must match what the code actually does. If you change a command, a dependency, or a default, update both.

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
# ❤️ Song Title (Artist Name)

## Section Name

Lyrics with [Chord] inline like this [Am] and here [G7].

## Resources

- [Song](https://youtube.com/...)
```

- **H1** = song title (one per file, shown as the slide title)
- **H2** = section (each becomes a sub-slide)
- **Chords** use `[ChordName]` inline in lyrics
- A `## Resources` section is automatically stripped from `print.html` (links are useless in print)
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

## Vendored reveal.js

`style/revealjs/` holds reveal.js **6.0.2** — only the five files the pages load (`dist/reveal.js`, `reveal.css`, `reset.css`, `theme/night.css`, `theme/serif.css`) plus its `LICENSE`. Everything under `style/` is deployed, so the rest of the release (tests, demo, other themes, `package-lock.json`) stays out. The paths match Pandoc's `revealjs-url`, which is why the `dist/` folder is kept.

To upgrade, copy those five files from `dist/` at the release's tag in the Git repository (`https://raw.githubusercontent.com/hakimel/reveal.js/<tag>/dist/…`), remove the two Google Fonts `@import`s from the start of `theme/night.css` again, rebuild and run the specs. Pandoc's template also loads the notes, search and zoom plugins from their reveal.js 5 paths; the song book uses none of them, and `build` removes those script tags.

6.0.2 is the minimum: it makes every slide but the current one `inert` ([hakimel/reveal.js#1587](https://github.com/hakimel/reveal.js/issues/1587)). With 6.0.1, `Tab` on the Introduction reached the table of contents' links, which reveal.js keeps rendered next door but invisible — 35 of 40 presses landed there.

**Fonts:** `style/fonts/` holds Montserrat 700 and Open Sans (400/700, with italics) as Google Fonts serves them — 25 woff2 files, every subset, with their OFL licenses — and `fonts.css` with Google's `@font-face` rules pointing at them. `post_process_index` links it; the night theme's own `@import`s from fonts.googleapis.com are removed, so no visitor's browser asks Google for anything.

`style/qrcodejs/` holds qrcodejs 1.0.0 (the 🔗 dialog's QR code) with its `LICENSE`, served from the song book itself rather than jsDelivr.

## Keyboard and dialogs

**The URL is written the moment the page is hidden** (`visibilitychange`): Reveal writes it at most once a second, and iOS stops that timer in the background, so a phone that switched apps right after a slide change and was discarded there reloaded a slide early.


**The two overlays are native `<dialog>`s** (🚀's password prompt and 🔗's QR code, in `style/body-controls.html`), opened with `showModal()`: the page behind is inert, Esc closes, and focus returns to the button that opened them. The QR dialog focuses its title (`tabindex="-1"`, no ring), so a screenreader starts there and a phone shows no keyboard; the password dialog focuses its field. Two things `showModal()` leaves to us: Reveal listens for keys on the document, where they still arrive from inside a dialog — so each dialog stops `keydown`/`keypress` from propagating, or the arrow keys would page the deck behind it and Esc would open Reveal's overview — and a click on the backdrop lands on the `<dialog>` itself, which closes it.

**Space on a focused button presses that button, and only that** (`keyboardCondition`, set with `Reveal.configure` on load): Reveal used to turn the page as well, so Space after 🌞 switched the theme back and moved on. The exception is a focus nobody can see: a mouse click leaves the button focused without a ring, and there Space blurs it and turns the page, as the one clicking expects. Whether the ring shows is read on `focusin`, because Chrome turns `:focus-visible` on as soon as any key is pressed.

**The buttons' labels are their tooltips.** Each control's `.visually-hidden` text is shown as a tooltip on hover (only where there is hover, `(hover: hover)`, so a tap on a phone shows nothing) and on keyboard focus. Esc hides it without opening Reveal's overview, any other key hides it too, and it stays hidden until the pointer leaves or the focus moves.

**Chords are buttons** (`style/chords.js`): `role="button"`, `tabindex="0"`, `aria-expanded`; Enter or Space opens the fingering, the tooltip is read out as it appears (`aria-live`). The key handler sits on `window`, so it runs after Reveal's and skips a key Reveal acted on — Space on a chord focused by a mouse click turns the page, like on any button (see above).

**Storage is optional:** with site data blocked, touching `localStorage` or `sessionStorage` throws, so every access is wrapped; the theme then switches without being remembered.

## Multiplex (live sync)

The presentation uses the [Reveal.js multiplex plugin](https://revealjs.com/multiplex/) via `multiplex.up.railway.app` so that audience members can follow the presenter's slides in real time on their own devices.

The code is the second `<script>` in `style/body-controls.html`; the server is a pure relay (one event, `multiplex-statechanged`, forwarded to everyone but the sender when `sha256(secret) == socketId`, no storage).

- **Master** (🚀, top right): click → enter the password → your slide changes are broadcast to all clients; ❌ on 🚀 while active, click again to stop. The role is kept per tab (`sessionStorage` `multiplex-master`, holding the claim below), so a master that reloads — or whose tab iOS discarded — leads again without the password.
- **One master leads: whoever took over last.** The relay stops nobody from sending, and the password ships in the page, so the tabs agree on a rule instead. Every message carries `claim`, the time its sender took over, and `from`, an id per page load. A master that hears a higher claim steps down and becomes a client; a takeover claims at least one above every claim it heard, so a device whose clock runs behind still wins. An equal claim is a duplicated tab (it inherited the role): between masters, the higher `from` stays. A client takes an equal claim as the same leader reloaded under a new id, and ignores a lower claim until the leader has been silent for `LEADER_SILENCE_MS` (65 s — a tab in the background for a while is woken only once a minute).
- **Heartbeat:** the master repeats its state every 2 s (`HEARTBEAT_MS`; the specs shorten it through `window.MULTIPLEX.heartbeat`) and again right after a reconnect. That is how a client that opens the page mid-session, or comes back from a dead spot or a locked screen, catches up — the relay cannot hand out a last state. Repeats are only sent while connected (socket.io would queue them all and replay them at once), and a client drops a repeat that matches where it already is.
- **Client** (default): follows the master. **Following is the client's own choice**, per tab (`sessionStorage`, so a reload or iOS discarding the tab keeps it): 👣 „Browse freely" switches it off and on, and switching it back on jumps to the master's last state straight away.
- **Paging on one's own device switches to browsing freely.** Otherwise the next repeat would snap the page back within two seconds — the reason a heartbeat was once rejected here. Reveal events the master caused (`applyingRemote`, set around `Reveal.setState`) don't count.
- **Only the slide is sent** (`stateToSend`): indices, never `overview` or `paused`. While the presenter browses the overview for the next song, the slide it was opened on is repeated, and the chosen one goes out when the overview closes; B pauses the presenter's screen only.
- **Status line** (`#multiplex-status`, `role="status"`, under the top-right buttons): „Du präsentierst", „Folgt", „Frei", „Niemand präsentiert" (no word from the presenter for three repeats) or „Keine Verbindung" (a connection that was there and dropped). Empty for someone who never heard a presenter, which is everyone browsing on their own.
- **QR code** (🔗, top right): shows a QR code of the current URL so new people can join.

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

The password is embedded in the generated HTML (visible in source). This is intentional — the goal is only to prevent accidental master takeover, not real security.

## Legacy songs

`content/legacy-songs/` holds songs removed from the active set. They are not included in the build.
