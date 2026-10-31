## 2026-10-31 — The corner buttons fade out, and come back on a tap

**Context:** Even with one button per corner (see [QR and 🚀 move into the live-scroll dialog](2026-10-31-qr-and-rocket-move-into-the-live-scroll-dialog.md)), four emojis framed every slide, and to the user the screen still felt busy. Most of the time nobody needs them: a song is read, and paged by swiping.

**Decision:** A few seconds after the page loads, the four buttons fade out slowly, a desktop's chevrons with them. The first time they show, their labels show too. A tap anywhere, a mouse that moves or the keyboard's focus brings them back, to fade again three seconds later.

**Reasoning:**
- **A tap anywhere, not on the button's spot.** On a tablet, nobody remembers where an invisible ⚙️ was; the user asked for it explicitly.
- **Not a swipe, not a paging key.** Those are how the book is read. If they brought the buttons back, the buttons would be up on every slide, and nothing would be gained.
- **Not a tap that does something of its own.** A tap on a chord shows its fingering, and the next tap elsewhere closes it; the user didn't want the buttons coming up for either. The same goes for a link, a button or the table of contents' filter, whose ends 📖 and ↕️ would cover.
- **Faded buttons take no taps.** Otherwise a tap meant to bring them back would open the settings unseen. The tap that brings them back presses nothing; the next one does. The browser hit-tests a tap's click only after the finger comes up, when the button is back already, so such a click is dropped by hand.
- **Some stay.** A button under the mouse or with the keyboard's focus, so a keyboard user never tabs onto something invisible. And 📡 while the connection is down: faded, nobody would notice that the live scrolling has stopped.
- **Labels once, not for good.** Shown permanently, „Table of contents", „Vollbild", „Settings" and the live-scroll status would crowd a phone's screen, which is what this was meant to stop. Once, at load, they say what the emojis are.
- **The specs keep the buttons.** Cuprite treats a faded button as invisible, and dozens of examples click them. A switch on every page (`window.CONTROLS_STAY`, Ferrum's `extensions`) keeps them, rather than each example waking them first; one example tests the fading itself.
