## 2026-09-30 — The buttons' labels are their tooltips

**Context:** The corner controls (📖 🎹 🔗 👣 🚀 🌞) show nothing but an emoji; their names existed only for screenreaders, as visually hidden text.

**Decision:** That same text is shown as a tooltip on hover and on keyboard focus — no second copy of the words. Hover only counts where the device has it (`(hover: hover)`). Esc hides a tooltip without opening Reveal's overview, any other key hides it as well, and it stays hidden until the pointer leaves or the focus moves; a transparent border bridges the gap to the button, so the pointer can move onto it (WCAG 1.4.13).

**Reasoning:** Taken over from Axipedia, where the same tooltips replaced written-out buttons. Without the hover check, a tap on a phone leaves a sticky hover and a tooltip nobody asked for. Hiding on any key keeps a button that happens to hold the focus from captioning the screen for a whole song.
