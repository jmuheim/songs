## 2026-09-30 — The overlays are native dialogs that keep the keys to themselves

**Context:** The QR overlay left the focus on 🔗, so its keydown guard never fired: the arrow keys paged the deck behind it and Esc opened Reveal's overview. `Tab` led out of the password overlay the same way. Neither had a heading, the password field had no label, the QR image no alt text.

**Decision:** Both are `<dialog>`s opened with `showModal()`, labelled by a heading. The QR dialog focuses its title (`tabindex="-1"`, no ring), the password dialog its field. Each dialog stops `keydown` and `keypress` from propagating, and a click on the backdrop closes it. 🔗 carries `aria-haspopup="dialog"` instead of `aria-pressed`.

**Reasoning:** `showModal()` brings the inert background, native Esc and focus return. What it does not do is keep keys from bubbling to the document, where Reveal listens — hence the explicit stop. Focusing the title rather than the close button lets a screenreader start at the top and keeps a phone's keyboard from popping up. A button that opens a modal dialog is not a toggle: nobody can „unpress" it while the dialog covers it.
