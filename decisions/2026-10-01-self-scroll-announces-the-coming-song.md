## 2026-10-01 — Self-scroll announces the coming song to the room

**Context:** In guest mode every client gets an invite dialog, so the audience knows a session has started and which song is next. In self mode — the presenter scrolls — clients were snapped into following silently, with no signal that a session had begun or what was being played.

**Decision:** When the presenter picks „Ich selber möchte scrollen", each client is shown „Der nächste Song ist «Song». Es geht gleich los!" with an OK button, once per session, and then follows along. The presenter sees no such dialog.

**Reasoning:** It mirrors the guest invite so both modes announce themselves — but self mode has nothing to volunteer for, so it's an acknowledgement (OK), not a choice. Shown once per session (`announcedFor`, keyed by the session id) so the 2 s heartbeat doesn't reopen it. It never blocks following: the deck moves under the dialog, so dismissing it is optional. The presenter is excluded because it is the one doing the scrolling. Builds on [live-scroll sessions, presenter delegates to a guest](2026-09-30-live-scroll-sessions-presenter-delegates-to-a-guest.md).
