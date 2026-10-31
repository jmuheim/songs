## 2026-10-28 — The iPhone's Vollbild swipes the page itself

**Context:** On an iPhone, Safari's bars take a good part of the screen. A web page usually gets rid of them with a swipe down: Safari hides its bars as the page scrolls. The song book never scrolls, because Reveal turns every swipe into a slide change. Safari on the iPhone has no Fullscreen API for a page either (only for `<video>`). Added to the home screen, the book does open without bars, but the user wanted a way that doesn't depend on that.

**Decision:** ↕️ in the top-right corner toggles full screen. Where the Fullscreen API exists, it uses that. On an iPhone it opens a „runway": for a moment the page itself becomes many screens tall, with the deck pinned in place underneath, and asks for a swipe down. Once the bars are gone, it says so and waits for OK; then the runway fades out but keeps the page's height and its scroll position, and the deck takes over again. A second press of ↕️ gives the room back. The runway also mentions the home screen, for those who want no bars at all.

**Reasoning:**
- **Not a scrolling dialog,** the first idea: Safari only hides its bars when the page's own scroll moves. A dialog scrolls in a box of its own, and the bars stay.
- **Not a scroll from a script:** Safari has ignored `scrollTo` for its bars since iOS 7, and `minimal-ui` was dropped in iOS 8. It takes a real finger.
- **The room stays after the runway:** when the page shrinks back to one screen, its scroll position drops to 0, and Safari shows its bars again at once. Kept tall and scrolled, the page stays as Safari left it, as long as nothing scrolls it back. Reveal's arrow keys don't, and its `touch-action` keeps the fingers off the deck, but not off a code block or the corner buttons: on the phone, a swipe there scrolled the page, so while the room is kept `holdPage` cancels every one-finger `touchmove` but those in the table of contents or a dialog (amended 2026-10-31).
- **The fit watches the deck, not `<html>`:** while the runway's room is kept, `<html>` is many screens tall in `vh`, a unit Safari doesn't change as its bars come and go, so the slides already shown never grew into the space gained. The deck, pinned to the screen, does change size.
- **It waits for OK once the bars are gone:** at first a 🎉 came and went on its own within a second, which left the user, trying it on the iPhone, wondering what had happened.
- **A corner button, not an entry in ⚙️:** first built into the settings dialog; the user wanted it one press away, and a second press to leave again.
- Tested on an iPhone by the user; the specs can only fake the bars with a taller window.
