## 2026-11-12 — The update dialog offers only „Neu laden"

**Context:** The dialog that offers a new build ([a new build offers itself in a dialog](2026-11-12-a-new-build-offers-itself-in-a-dialog.md)) had a „Später" beside „Neu laden", and closed on Esc and on a tap beside it, like every other dialog in the song book. Its text asked „Jetzt neu laden? Du bleibst auf dieser Folie." The user found „Später" unnecessary, and the text too long.

**Decision:** The dialog says „Neue Version", „Eine neue Version des Liederbuchs ist da." and offers „Neu laden", nothing else. A tap on its backdrop no longer closes it. Esc still does.

**Reasoning:** A reload costs nothing here: the slide, the session, its role and its live scroll all survive it. So there is nothing to put off. Without „Später", a tap beside the dialog would have been a hidden „Später", easily hit by a stray finger on a phone, so that goes too. Esc stays for two reasons. A modal dialog's Esc is the browser's own, and Chrome no longer lets a page stop it more than once without a user gesture. And a keyboard user should not be held in a dialog by force. Whoever closes it that way gets the new build on the next visit, as before.
