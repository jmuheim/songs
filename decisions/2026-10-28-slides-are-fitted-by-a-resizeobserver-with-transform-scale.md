## 2026-10-28 — Slides are fitted by a ResizeObserver, with transform: scale()

**Context:** Fitting slides to the screen felt unreliable. Four problems, each confirmed in Chrome:
- **Overview:** `slide-zoom.js` only ever fitted the current slide, so 69 of the 70 slides the overview shows had no fit at all.
- **Picking a slide in the overview:** a slide fitted while the overview was open was measured in the overview's layout (zoom 1 where 2.23 was right), and nothing re-fitted it once the overview closed.
- **Reload:** the first fit waited for the window's `load` event, so the first frames painted the slide unfitted (first paint at 320ms, fit at 353ms locally; longer on the live site, where `load` also waits for socket.io from the relay's host).
- **Missed changes:** anything that changed a slide's size without a slide change, like hiding the chords in the settings, left a stale fit. Every such trigger had to be hooked up by hand, and late fonts already had a special case of their own.

**Decision:**
- **What gets fitted, and when:** every rendered slide, whenever its size could change. A `ResizeObserver` watches every slide's `.slide-content`, the page and the right chevron, and fits with `transform: scale()` instead of CSS `zoom`.
- **No unfitted frames:** until its first fit, a slide's content is invisible, with a one-second CSS fallback that shows it anyway should the script never run. `slide-zoom.js` loads before the socket.io script.
- **Overview layout:** the fitted contents are `align-self: center`.
- **Chevrons:** the fit also leaves room for the up/down chevrons, not just the side ones.

**Reasoning:**
- **Why a `ResizeObserver`:** it turns "remember every trigger" into "react to any size change". Its callbacks run after layout and before paint, which is what makes a fit land in the same frame as the change it reacts to: a slide appearing, fonts swapping in, chords hidden.
- **Why a transform, not `zoom`:** the observer needs a transform. `zoom` changes the layout, so applying it would resize the observed element and set the observer off again; worse, below 1 it re-wrapped the text at a wider measure than had been measured, so a long slide could still spill under a chevron. A transform leaves the layout untouched, and what is measured is exactly what is scaled.
- **The cost of the transform:** `getComputedStyle` no longer includes the scale. `chords.js` now multiplies the chord's computed font size by the rendered-over-layout ratio to size its tooltip.
- **Why hide unfitted content:** hiding beats racing the first paint. Even with the script loaded early, a browser may paint between Reveal's initialisation and the first observer callback; a blank frame is better than a wrong-size one. The animation fallback keeps a failed script from leaving the book blank.
- **Why `align-self: center`:** the overview sets every slide to the full screen height, and flex's default stretch made the content measure that height. Every overview slide came out capped at scale 1.
- **Top/bottom gutters:** once the up/down chevrons appeared at the top and bottom centre, slides filling the height ran their last line under ˅. They get the same treatment as the side chevrons: room as deep as the chevrons reach in, measured from layout offsets.
- **Rejected, patching each gap:** re-fit on `overviewhidden`, skip fitting during the overview, load earlier, hook the chords toggle. It would have kept the fragility that caused the problems, and the overview would still have shown unfitted slides unless all of them were fitted before it opened.
