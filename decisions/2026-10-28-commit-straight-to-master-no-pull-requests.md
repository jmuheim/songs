## 2026-10-28 — Commit straight to master, no pull requests

**Context:** Every change went on a branch of its own off `master`, through a pull request, and was merged by hand once CI was green. The working agreements also had Claude ask, before any new work, which branch and which checkout it should land in. For a small, private song book with essentially one author, that round trip cost more than it caught.

**Decision:** Commit new work straight to `master` and push it. No feature branches and no pull requests, and no asking where the work lands. A parallel session that can't use the main checkout works in a git worktree on a short-lived local branch, which it rebases onto `master` and fast-forwards `master` to.

**Reasoning:** The review step a pull request adds was the author reviewing their own change. What actually guards the site doesn't depend on a pull request: the full suite runs locally before each push, and CI runs it again on the push to `master` and deploys only once that run is green (`needs: rspec`). A red push therefore leaves songs.josh.ch on the last green build until it is fixed. A worktree's branch only exists because git won't check out `master` twice, and it is fast-forwarded into `master`, never merged through GitHub. The old rule against `gh pr merge --auto` (which merged #52 while CI was still red) goes away with the pull requests.
