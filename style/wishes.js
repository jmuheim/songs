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
// too should the multiplex script never run. See
// decisions/2026-11-11-guests-wish-for-songs-with-a-heart-counted-per-session.md.
(function () {
  function init() {
    var buttons = Array.prototype.slice.call(document.querySelectorAll('button.song-wish'));
    if (!buttons.length) return;

    var label = buttons[0].querySelector('.visually-hidden').textContent;
    var onToggle = null;
    var mine = {};   // slug → true: this device's wishes
    var counts = {}; // slug → devices in the session wishing the song

    function render() {
      buttons.forEach(function (button) {
        var slug = button.getAttribute('data-song');
        var count = counts[slug] || 0;
        var wished = !!mine[slug];
        button.setAttribute('aria-pressed', wished ? 'true' : 'false');
        button.querySelector('.song-wish-count').textContent = count ? String(count) : '';
        button.querySelector('.visually-hidden').textContent =
          label + ', ' + (count === 1 ? '1 Wunsch' : count + ' Wünsche');
      });
    }

    buttons.forEach(function (button) {
      button.addEventListener('click', function () {
        if (onToggle) onToggle(button.getAttribute('data-song'));
      });
    });

    window.songWishes = {
      // Called with the song's slug when a heart is pressed; body-controls.html
      // toggles the wish and calls setMine/setCounts back
      onToggle: function (fn) { onToggle = fn; },
      // This device's wishes, as slugs
      setMine: function (slugs) {
        mine = {};
        slugs.forEach(function (slug) { mine[slug] = true; });
        render();
      },
      // The room's tally, slug → number of devices
      setCounts: function (tally) {
        counts = tally || {};
        render();
      },
      // In a session the hearts show; outside one they are hidden
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
