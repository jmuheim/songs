## 2026-09-30 — The presenter repeats its slide; each client chooses whether to follow

**Context:** A client that opened the song book mid-session stayed where it was until the presenter moved on, and so did one coming back from a dead spot or a locked screen. The public multiplex server is a pure relay and cannot hand out a last state. A heartbeat had been considered and rejected because it would snap free-browsing clients back every few seconds.

**Decision:** The presenter repeats its state every 2 s and right after a reconnect; a client drops a repeat that changes nothing. Following is each client's own choice, per tab (`sessionStorage`): 👣 „Browse freely" switches it off and on, and switching it back on jumps to the presenter's slide. Paging on one's own device switches to browsing freely.

**Reasoning:** Axipedia lets the presenter decide whether the room follows, and a following client there cannot page at all. At a campfire the audience are the ones holding the phones — someone looks up the chord table while the song goes on — so the choice belongs to them. Treating one's own paging as the switch is what makes the heartbeat acceptable: otherwise the next repeat would pull the page away from under the thumb that just turned it. Nothing is sent while disconnected, because socket.io would queue every repeat and replay them all at once.
