## 2026-10-01 — Ending a session returns everyone to the table of contents

**Context:** When the presenter ended a live-scroll session, everyone was simply freed to navigate — each left standing on the song that had just finished, with no shared next step.

**Decision:** Ending a session navigates the presenter and every follower to the table of contents (`gotoToc`, the `#TOC` slide). A silent timeout — a follower that loses the session's heartbeat — still frees itself *where it stands*, without the jump.

**Reasoning:** A deliberate end means "this song is done"; dropping the whole room on the TOC gives one obvious place to choose what comes next, instead of scattering everyone on a finished song. The silent timeout is a different event — not the presenter declaring the song over, just a dropout — so yanking that follower to the TOC would misread a lost connection as an ending; it frees in place and re-locks on the presenter's next heartbeat. See [a follower that hears nothing frees itself](2026-09-30-live-scroll-sessions-presenter-delegates-to-a-guest.md).
