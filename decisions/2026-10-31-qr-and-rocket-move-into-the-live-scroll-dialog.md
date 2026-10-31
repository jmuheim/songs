## 2026-10-31 — QR and 🚀 move into the live-scroll dialog

**Context:** With ↕️ added, six controls sat in the corners: 🔗 and 📖 top left, ↕️ and ⚙️ top right, the multiplex status dot bottom left, 🚀 bottom right on songs. To the user the screen felt overloaded. The top corners also covered the table of contents' filter bar: 📖 lay over „Sprache", and ↕️ over „Reset", whose click CI's Chrome then landed on ↕️.

**Decision:** One control per corner. 📖 top left, ↕️ top right, 📡 bottom left, ⚙️ bottom right. 📡 opens the live-scroll dialog (the old status dialog), which now holds 🚀 („Live-Scrollen starten"/„beenden") and 🔗 („QR-Code zeigen"). The status dot becomes a badge on 📡. 🚀 is disabled off a song, with a hint saying why, where it used to be hidden.

**Reasoning:**
- **Both belong to live scrolling.** The QR code is there so others can join and follow along, and 🚀 is for the presenter alone. Most people in the room never need 🚀 at all, so it shouldn't take a corner of their screen.
- **The cost is a tap.** Ending a session now takes 📡 and then 🚀. A presenter does that once per song, and in return everyone else sees one button less.
- **📡, not a bare dot,** because the dot alone gave no hint that QR and 🚀 were behind it.
- **Disabled, not hidden, inside the dialog:** a button that appears and disappears in a corner says „only here" by its absence; in a dialog a missing button just looks like a missing feature, so it stays, greyed, with the reason beside it.
- **⚙️ bottom right,** the user's choice, which also leaves each top corner with a single button. That frees the middle of „Reset" again, but the filter bar still runs under 📖 and ↕️ at its ends. Starting it below the corner buttons was tried and dropped: it cost the table of contents a row of height, and the user means to rework the filter bar anyway.
