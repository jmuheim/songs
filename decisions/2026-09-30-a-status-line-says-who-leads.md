## 2026-09-30 — A line of text says who leads and whether this phone follows

**Context:** A phone that stopped moving gave no clue why: the presenter might have left, the connection dropped, or its owner had paged away and was browsing freely.

**Decision:** A status line under the top-right buttons (`role="status"`): „Du präsentierst", „Folgt", „Frei", „Niemand präsentiert" after three missed repeats, or „Keine Verbindung" once a connection that was there has dropped. It stays empty for anyone who never heard a presenter.

**Reasoning:** Axipedia encodes this in the shape of a lamp and puts the words into a tooltip; the song book has no tooltips on phones and an audience that did not learn a symbol, so the words themselves are shown. Empty for solo browsing, because „Niemand präsentiert" on every visit of someone singing alone is noise. „Keine Verbindung" only after a first connect, so a page load does not flash it.
