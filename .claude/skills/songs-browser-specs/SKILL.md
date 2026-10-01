---
name: songs-browser-specs
description: Conventions for this repo's Capybara/Cuprite browser specs (spec/browser/*_spec.rb) — prefer Capybara's waiting matchers and the repo's poll helpers over injected JavaScript, extend an existing example before adding one, make every new assertion able to fail, and the Cuprite/Reveal traps that have bitten here (the mouse stays where it clicked, real reloads need page.refresh, Reveal scales the slide so computed px are not CSS px, the fixed multiplex port, hover can't be CDP-emulated, :focus-visible flips on focusin). Use when writing or editing any browser spec.
paths: "spec/browser/**"
---

# Songs browser specs — conventions

The browser specs drive headless Chrome through Capybara → Cuprite → Ferrum → CDP. **Solve each step at the highest level that works, and justify any drop below Capybara with a comment.** Injected JavaScript (`evaluate_script`) is the last resort — it skips Capybara's waiting and hides intent.

## Reach for the waiting layer first

- **Capybara matchers and actions** wait and retry: `have_css` / `have_no_css` / `have_text` (with `text:`, `count:`, `visible: :all/:hidden`), `find`, `click`, `hover`, `click_button`, `click_link`. The custom `have_visible` matcher is in `spec/spec_helper.rb`. Prefer these over reading the DOM yourself.
- **For state Capybara can't see** — Reveal's indices, an inline `style="zoom: …"`, `document.activeElement` — poll with the helpers already in `spec/spec_helper.rb`: `wait_for_reveal`, `wait_for_js(condition)`, `press(*keys)`, `active_element_id`. Never a fixed `sleep`.
- **`press` types into whatever has focus** (`keyboard.type`). Do **not** use `send_keys` on a node to test key handling: Cuprite clicks the node first, which moves focus — `press` exists precisely to avoid that.
- Drop to `page.driver.browser.mouse` / `.page.command('…')` (raw CDP) only for what Ferrum/Capybara can't express, and say why at the call.

## Extend before you add

`capybara/rspec` resets the session around every example, so each one re-visits and re-runs Reveal's init — a deck load costs roughly a second, an extra assertion on an already-loaded page costs nothing. So **look for an example that already loads the right page and add to it**:

- Group by page state (one example per URL × mutation). Fold pure reads of the same page into one example wrapped in `aggregate_failures`, with a comment per assertion carrying what a separate example's name would have said.
- A new example earns its keep only with a new page state — a different URL, or a mutation (click, key, injected class) a later read must not see. Otherwise fold it into the neighbour.
- Don't let a `before { load_presentation }` run for an example that then navigates away — split that example into a sibling `describe` without the hook.

## Make a new check able to fail

A spec that stays green whether or not the behaviour works is worthless. After writing one, break the behaviour locally (comment out the handler, change the value) and confirm the spec goes red. This is the bar for every assertion, not just browser ones.

## Traps that have bitten here

- **The mouse stays where it last clicked or hovered.** After a click the pointer sits on that element, so keys pressed next land on its hover state (e.g. dismiss its tooltip, or page the deck). Move it away first — `page.driver.browser.mouse.move(x: 640, y: 500)` — before a keyboard sub-test. See the 🎹 toggle example in `index_html_spec.rb` ("The mouse leaves first: keys pressed while it rested on 🎹 dismissed its tooltip").
- **Reveal scales the slide, so computed px are not the CSS px.** A `3px` outline comes back as `2.58px`; font sizes are scaled too. Assert the **colour and style**, never the pixel width — `getComputedStyle(el).outlineStyle + ' ' + outlineColor` → `'solid rgb(255, 255, 255)'` in `chord_tooltips_spec.rb`. Where a number is unavoidable (`mobile_spec.rb`'s font size), compare with `be_within`, not `eq`. The one place an exact scaled value *is* pinned — the title slide's `zoom` — only holds locally; on CI it is range-checked, because colour-emoji layout differs across Chrome builds.
- **A real reload is `page.refresh`, not `visit` on the same URL.** Visiting the same `#/…` only jumps within the loaded deck; it never re-runs page load. Use `page.refresh` (see the presenter-reload examples in `index_html_spec.rb`).
- **Ports.** `spec/support/file_server.rb` serves the project on `127.0.0.1` on an **OS-picked free port**, so a second checkout's run doesn't collide. `spec/support/multiplex_server.rb` is **fixed on `127.0.0.1:18889` and refuses to start if that port is taken** — so the specs never quietly broadcast into a multiplex server left over from a manual test. Run manual multiplex tests on a different port.
- **`:focus-visible` flips on `focusin`, not on the first keydown.** Chrome enables `:focus-visible` as soon as any key is pressed, so the page reads the ring's visibility on `focusin`; a mouse click leaves a focus with no ring. A spec asserting the ring must account for this (focus by keyboard to see it, by click not to).
- **Not every media feature can be emulated.** CDP `Emulation.setEmulatedMedia` does **not** support `hover`, so a tooltip gated on `matchMedia('(hover: hover)')` can't be forced that way on the Linux runner. Simulate the pointer instead by patching `matchMedia` before the page's own scripts capture it, via `Page.addScriptToEvaluateOnNewDocument` — see the QR-modal example.

## Before you commit

The specs are timing-sensitive; one green run proves little. Run the changed file a handful of times and expect all green — a 1-in-5 flake is a real defect, not noise. Then run the whole suite (`bundle exec rspec`): it rebuilds the fixtures and the golden snapshots too, so a markup change surfaces there.
