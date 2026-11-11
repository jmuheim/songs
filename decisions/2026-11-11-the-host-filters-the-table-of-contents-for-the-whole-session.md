## 2026-11-11 — The host filters the table of contents for the whole session

**Context:** In a session the host already sets the Gastgeber checkboxes for everyone ([the host sets who is present for the whole session](2026-10-31-the-host-sets-who-is-present-for-the-whole-session.md)), but Sprache and Genre stayed each guest's own filter. On an evening that splits the room: the host narrows the list to, say, the German songs, and every guest still looks at the whole book, or at a filter of their own. The ask was plain: when the host filters, the guests get that filter, and can't filter on their own.

**Decision:** In a session the whole table-of-contents filter is the host's. Sprache and Genre (`filter`, `{ sprache, genre }`) ride on the host's heartbeat next to `present`, are stored with the session on every device and go along with a takeover. Every list in the session shows what the host's shows. The guests' selects and „Zurücksetzen" are disabled, like their Gastgeber checkboxes. The host's „Zurücksetzen" clears Sprache and Genre for everyone and still leaves the Gastgeber alone. A new session starts unfiltered, and leaving one gives the filter back, nothing filtered. Outside a session nothing changes: the filter is one's own.

**Reasoning:**
- **One list for the room.** The point of a session is that everyone looks at the same thing. A guest filtering on top of the host's choice could only hide songs the host offered.
- **The same path as `present`.** Sprache and Genre go through the mechanism the Gastgeber checkboxes already use: the heartbeat, the stored session, the takeover, one `setSession` call in `toc-filter.js`. No second channel, no second message type.
- **Disabled, not hidden.** Greyed-out selects still say what the list is filtered by. Selects that vanished would leave a guest wondering why songs are missing. The dialog's info line says who chooses.
- **The host's filter is everyone's, even for a quick look-up.** The host can no longer filter privately in a session. We accepted that for one list everybody shares. The host's info line in the „Lieder von" dialog says so („Auch Sprache und Genre wählst du für alle").
- **„Zurücksetzen" still leaves the Gastgeber alone.** Who is here is a fact about the evening, not a filter (see the earlier entry). Resetting it along with Sprache and Genre would bring back the songs of people who went home.

Supersedes „Sprache and Genre stay each guest's own filter" in [the host sets who is present for the whole session](2026-10-31-the-host-sets-who-is-present-for-the-whole-session.md).
