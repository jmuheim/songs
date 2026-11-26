// The ❤️ on each song: a guest's wish to sing it, in a session. The build
// (wish_button in lib/build_helpers.rb) puts one button.song-wish in the
// song's row of the table of contents and one on its title slide, both with
// the song's slug as data-song; this wires them. It owns what shows — the
// heart's fill (aria-pressed: this device wishes the song), the count of
// devices in the session that wish it, and whether the hearts show at all —
// and nothing of the room: body-controls.html keeps this device's wishes,
// carries them over multiplex and tallies everyone's, and drives this through
// window.songWishes. Outside a session there is no room to count, so the
// hearts stay hidden (body.wishes-active, shared.css) — and they stay hidden
// too should the multiplex script never run — but on a host's device, where
// they are its playlist. A playlist shows a ⭐ instead of the ❤️, and each
// song's place on it (ranks) rather than a count: another shape, not just
// another colour, which not everyone tells apart. The songs played this
// evening wear a ✓, and a
// guest's hearts are only to read while the host alone makes the playlist.
// See decisions/2026-11-11-guests-wish-for-songs-with-a-heart-counted-per-session.md
// and decisions/2026-11-26-the-hosts-playlist-and-the-next-song-button.md.
(function () {
  function init() {
    var buttons = Array.prototype.slice.call(document.querySelectorAll('button.song-wish'));
    if (!buttons.length) return;

    var label = buttons[0].querySelector('.visually-hidden').textContent;
    var heart = buttons[0].querySelector('.song-wish-heart').textContent;
    var PLAYLIST_LABEL = 'Auf die Playlist';
    var PLAYLIST_SYMBOL = '⭐';
    var onToggle = null;
    var mine = {};    // slug → true: this device's wishes (or the playlist's songs)
    var counts = {};  // slug → devices in the session wishing the song
    var ranks = null; // slug → place on the playlist, instead of the counts
    var played = {};  // slug → true: played this evening
    var enabled = true;

    // Only what changed: a slide's size is watched (slide-zoom.js), and the
    // tally comes in every few seconds
    function setText(el, text) {
      if (el.textContent !== text) el.textContent = text;
    }

    function render() {
      buttons.forEach(function (button) {
        var slug = button.getAttribute('data-song');
        var wished = !!mine[slug];
        var text;
        button.setAttribute('aria-pressed', wished ? 'true' : 'false');
        button.disabled = !enabled;
        button.classList.toggle('song-played', !!played[slug]);
        setText(button.querySelector('.song-wish-heart'), ranks ? PLAYLIST_SYMBOL : heart);
        if (ranks) {
          var rank = ranks[slug];
          setText(button.querySelector('.song-wish-count'), rank ? rank + '.' : '');
          text = PLAYLIST_LABEL + (rank ? ', Platz ' + rank : '');
        } else {
          var count = counts[slug] || 0;
          setText(button.querySelector('.song-wish-count'), count ? String(count) : '');
          text = label + ', ' + (count === 1 ? '1 Wunsch' : count + ' Wünsche');
        }
        setText(button.querySelector('.visually-hidden'), text + (played[slug] ? ', gespielt' : ''));
      });
    }

    buttons.forEach(function (button) {
      button.addEventListener('click', function () {
        if (onToggle) onToggle(button.getAttribute('data-song'));
      });
    });

    window.songWishes = {
      // Called with the song's slug when a heart is pressed; body-controls.html
      // toggles the wish and calls show back
      onToggle: function (fn) { onToggle = fn; },
      // What the hearts show: which are pressed (mine: this device's wishes,
      // or the playlist's songs), the room's tally (counts, slug → devices),
      // a playlist's places instead (ranks, slug → 1, 2, …; null for the
      // counts), the songs played this evening (played, as slugs) and
      // whether they take a press (enabled: not a guest's while the host
      // alone makes the playlist). All at once, so they render once.
      show: function (state) {
        mine = {};
        (state.mine || []).forEach(function (slug) { mine[slug] = true; });
        counts = state.counts || {};
        ranks = state.ranks || null;
        played = {};
        (state.played || []).forEach(function (slug) { played[slug] = true; });
        enabled = state.enabled !== false;
        render();
      },
      // In a session the hearts show, and on a host's device; elsewhere they
      // are hidden
      setActive: function (active) {
        document.body.classList.toggle('wishes-active', !!active);
      }
    };

    render();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
