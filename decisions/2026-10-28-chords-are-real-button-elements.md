## 2026-10-28 — Chords are real button elements

**Context:** [Chords are buttons](2026-09-30-chords-are-buttons.md) made each chord pressable by giving Pandoc's `<code>` `role="button"` and `tabindex="0"` at runtime, plus a key handler of its own for Enter and Space. The user asked for real `<button>` elements instead.

**Decision:**
- **Markup:** `chord_buttons` (`lib/build_helpers.rb`, in `post_process_index`) wraps each chord's `<code>` in `<button type="button" class="chord">` at build time. Only classes `a`–`g` and `x` are wrapped, the ones `chords.js` has a fingering for.
- **Not in print:** `print.html` keeps the bare `<code>`; there is nothing to press on paper.
- **Styling:** the `<code>` stays the coloured pill. The button shows nothing of its own (`all: unset`), and the focus/hover ring is drawn around the pill.
- **Script and keys:** `chords.js` only adds `aria-expanded`/`aria-controls` and opens the fingering on the click. Focus, Enter and Space are the browser's own, and its Enter/Space handler is gone. `keyboardCondition` now recognises buttons by tag alone, since nothing carries `role="button"` any more.
- **Hidden chords:** hiding them in ⚙️ hides the button with its pill.

**Reasoning:**
- **Why a native button:** it gets focus, Enter, Space and its role from the browser, with none of that re-implemented. The old handler had to second-guess Reveal's key handling: it listened on `window` to see whether Reveal had used a key first. Now `keyboardCondition`, which already handles every other button, decides alone.
- **Why wrap the `<code>` rather than replace it:** every chord style (the per-letter colours, `code.x`, the pill's padding and radius) and `print.html` keep working unchanged. The pinned slide-zoom values didn't move either, because the layout is the same as before. A bare `<button class="chord a">` would have needed every chord rule written twice, once for the button and once for print's `<code>`.
- **Why hide the button with the chords:** with only its `<code>` hidden, the empty button would still have been a Tab stop.
- **At build time, not in `chords.js`:** the markup is real buttons from the start, the golden fixtures pin it, and a unit spec covers which `<code>`s are wrapped. Swapping elements at load would have changed every slide's DOM after the first fit.
