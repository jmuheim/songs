## 2026-11-12 — The specs' multiplex server takes any free port

**Context:** The specs' own relay (`spec/support/multiplex_server.rb`) listened on the fixed port 18889, because the fixture carries its URL. The fixture is rebuilt at the start of every run, in its own checkout, but it is built before any spec starts the server, so the URL had to be known before the server was. With two Claude sessions working in two worktrees at once, their runs kept colliding there: the second run refused to start („port 18889 is taken"), or its relay died on startup mid-run. One afternoon cost several full runs that way, failures that had nothing to do with the code.

**Decision:** The relay is started with `PORT=0`, so the OS picks a free port. `multiplex-server/localhost.js`, which already wraps `listen` to keep the server on 127.0.0.1, writes the port it got to the file named by `PORT_FILE`. `MultiplexServer.url` starts the server if it hasn't started yet, waits for that file and the server's answer, and only then returns the URL, so the fixture's build gets the real port. The check for a taken port is gone.

**Reasoning:**
- **Rejected, picking a free port in Ruby first:** binding port 0, reading the number and handing it to node is shorter. But the port stays free between the fixture's build and the server's start, seconds apart with Pandoc in between, and another run could take it. Letting node bind it and report it leaves no such gap.
- **What it costs:** a run that only builds the fixture (the golden specs on their own) now starts node too, for about half a second.
- **What it brings:** the guard against broadcasting into a leftover manual-test server is not needed any more. That server simply sits on another port.
