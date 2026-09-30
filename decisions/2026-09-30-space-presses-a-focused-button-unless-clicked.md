## 2026-09-30 — Space presses a focused button, unless a mouse click put the focus there

**Context:** Space on a focused button pressed it *and* turned the page: Space after 🌞 switched the theme back and moved on. 🎹 avoided it with `blur()`, which cost keyboard users their place.

**Decision:** `keyboardCondition` leaves Space to a focused button. The exception is a focus nobody sees: where a mouse click put the focus there and no focus ring shows it, Space blurs the button and turns the page. Whether the ring shows is read on `focusin`.

**Reasoning:** Axipedia gives Space to the button every time. For a mouse user that is a trap: Chrome focuses a clicked button without showing it, and the next Space re-presses a button they cannot see is focused. „Does the ring show?" matches what the person sees. It has to be read when the focus arrives, because Chrome turns `:focus-visible` on as soon as any key is pressed — checking in the key handler itself always saw a ring.
