## 2026-10-29 — Commit after the user's review, push only when asked

**Context:** [Commit straight to master, no pull requests](2026-10-28-commit-straight-to-master-no-pull-requests.md) had Claude commit new work on `master` and push it, without asking. The user wants to look at a new change, and correct it, before it is committed. And a push is more than a sync: CI deploys every green push to `master` to songs.josh.ch.

**Decision:** There is still no question about the branch: new work goes onto `master`. But Claude commits it only after the user has reviewed the change and given an OK, with their corrections worked in. It pushes only when the user asks, and says after a commit how far `master` is ahead of `origin/master`.

**Reasoning:** The 2026-10-28 rule removed the pull request because its review step was the author reviewing their own change. The review itself is still wanted, and it belongs before the commit: a correction worked in first leaves one clean commit, not a commit and its fix-up. The question that rule removed, which branch the work goes on, stays removed, since the answer is always `master`. A push is asked about separately because it publishes, and the user may want to collect several reviewed commits before anything goes live. Rejected: pushing on every green local run, which put a change on the live site within minutes of writing it.
