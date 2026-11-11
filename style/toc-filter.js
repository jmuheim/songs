// Filters the table of contents by tag. The build (inject_toc_filter in
// lib/build_helpers.rb) renders the <fieldset id="toc-filter"> (one <select>
// each for Sprache/Genre, a „Lieder von" button for Gastgeber, plus a „Zurücksetzen"
// button), the <dialog id="gastgeber-modal"> that button opens, with the
// Gastgeber as checkboxes, a data-sprache / data-genre / data-gastgeber
// attribute on each song's <li>, and a hidden <p id="toc-filter-empty"> for
// when a filter leaves nothing standing; this only wires the controls. Sprache and Genre
// combine with AND (a song must match the selected value in each category
// that has one); Gastgeber's checkboxes combine with OR among themselves (a
// song matches if it names *any* checked host; all of them start out checked,
// and with all checked there is no filter, so a song without a Gastgeber
// stays), then AND into the rest — see
// decisions/2026-10-05-gastgeber-filter-uses-checkboxes-not-a-select.md. An
// untagged entry hides while any filter is active. „Zurücksetzen" clears every
// control. The selects, checkboxes and the button are real form controls, so
// the keyboardCondition in body-controls.html already keeps their keys from
// reaching Reveal. Outside a session the selection is this client's own; in
// one it is the host's, for everyone, but for a Sprache or Genre the host
// left at „Alle" (setSession below).
(function () {
  function init() {
    var bar = document.getElementById('toc-filter');
    if (!bar) return;

    var sprache   = document.getElementById('toc-filter-sprache');
    var genre     = document.getElementById('toc-filter-genre');
    var gastgeber = Array.prototype.slice.call(document.querySelectorAll('.toc-filter-gastgeber'));
    var reset     = document.getElementById('toc-filter-reset');
    var items     = Array.prototype.slice.call(document.querySelectorAll('#TOC nav li'));
    var empty     = document.getElementById('toc-filter-empty');
    var openBtn   = document.getElementById('toc-filter-gastgeber-open');
    var selection = openBtn && openBtn.querySelector('.toc-filter-selection');
    var dialog    = document.getElementById('gastgeber-modal');
    var info      = document.getElementById('gastgeber-info');
    var inSession = false;
    var hosting = false; // in a session, as its host
    var onSessionChange = null;

    function matches(li, select, attr) {
      if (!select || !select.value) return true; // that category has no filter active
      var values = (li.getAttribute(attr) || '').split(',');
      return values.indexOf(select.value) !== -1;
    }

    function matchesGastgeber(li) {
      var checked = checkedHosts();
      if (checked.length === gastgeber.length) return true; // every host checked, no filter active
      var values = (li.getAttribute('data-gastgeber') || '').split(',');
      return checked.some(function (v) { return values.indexOf(v) !== -1; });
    }

    function checkedHosts() {
      return gastgeber.filter(function (cb) { return cb.checked; }).map(function (cb) { return cb.value; });
    }

    function render() {
      if (selection) {
        var checked = checkedHosts();
        selection.textContent = checked.length === gastgeber.length ? 'Alle' : checked.join(', ') || 'Niemand';
      }
      var anyVisible = false;
      items.forEach(function (li) {
        var shown = matches(li, sprache, 'data-sprache') && matches(li, genre, 'data-genre') && matchesGastgeber(li);
        li.classList.toggle('toc-hidden', !shown);
        if (shown) anyVisible = true;
      });
      if (empty) empty.classList.toggle('toc-hidden', anyVisible);
    }

    // A change of one's own. In a session, the host's is every list's
    function changed() {
      render();
      if (hosting && onSessionChange) {
        onSessionChange({ present: checkedHosts(), sprache: sprache ? sprache.value : '', genre: genre ? genre.value : '' });
      }
    }

    [sprache, genre].forEach(function (select) {
      if (select) select.addEventListener('change', changed);
    });
    gastgeber.forEach(function (checkbox) {
      checkbox.addEventListener('change', changed);
    });

    if (reset) {
      reset.addEventListener('click', function () {
        // A disabled select is the host's, not this guest's to clear
        if (sprache && !sprache.disabled) sprache.value = '';
        if (genre && !genre.disabled) genre.value = '';
        // In a session the Gastgeber are whose songs the evening has, not a filter
        if (!inSession) gastgeber.forEach(function (checkbox) { checkbox.checked = true; });
        changed();
      });
    }

    // The dialog behind the „Lieder von" button. Like the others in
    // body-controls.html it keeps its keys from Reveal, which listens on the
    // document, and closes on a click on its backdrop.
    var INFO = {
      own: 'Zeigt die Lieder der angehakten Gastgeber. Wer abgehakt ist, fehlt in der Liste.',
      host: 'Wer ist heute Abend dabei? Alle in der Runde sehen nur die Lieder der angehakten Gastgeber. Wählst du eine Sprache oder ein Genre, gilt das auch für alle; bei „Alle" filtern die Gäste selbst.',
      guest: 'Der Gastgeber wählt für alle in der Runde, wessen Lieder heute Abend gespielt werden können. Wählt der Gastgeber eine Sprache oder ein Genre, gilt das auch für alle.'
    };
    if (dialog) {
      if (openBtn) openBtn.addEventListener('click', function () { dialog.showModal(); });
      document.getElementById('gastgeber-ok').addEventListener('click', function () { dialog.close(); });
      dialog.addEventListener('keydown', function (e) { e.stopPropagation(); });
      dialog.addEventListener('keypress', function (e) { e.stopPropagation(); });
      dialog.addEventListener('click', function (e) { if (e.target === dialog) dialog.close(); });
    }

    // In a session the filter stops being one's own: the Gastgeber checkboxes
    // say whose songs this evening has (`present`), and a Sprache or Genre the
    // host picks holds for every list in the session too. The host sets them
    // for everyone — body-controls.html carries them in its heartbeat — and
    // only the host can change them (`editable`); the guests see them as set,
    // but disabled. A Sprache or Genre the host leaves at „Alle" is each
    // guest's own: kept as the guest set it, from „Alle" again once the host
    // lets go of one, and „Zurücksetzen" clears it. `session` null: no
    // session, and the controls are one's own again, nothing filtered.
    window.tocFilter = {
      setSession: function (session, editable) {
        inSession = !!session;
        hosting = inSession && editable;
        var locked = inSession && !editable;
        [[sprache, 'sprache'], [genre, 'genre']].forEach(function (pair) {
          var select = pair[0];
          var value = inSession ? session[pair[1]] : '';
          if (!select) return;
          if (!locked || value) select.value = value;
          else if (select.disabled) select.value = ''; // the host let go of it
          select.disabled = locked && !!value;
        });
        var own = [sprache, genre].some(function (select) { return select && !select.disabled; });
        if (reset) reset.disabled = locked && !own;
        gastgeber.forEach(function (checkbox) {
          checkbox.checked = !inSession || session.present.indexOf(checkbox.value) !== -1;
          checkbox.disabled = locked;
        });
        if (info) info.textContent = !inSession ? INFO.own : editable ? INFO.host : INFO.guest;
        render();
      },
      // Whether any song names a Gastgeber, i.e. there is anyone to tick
      hasHosts: function () { return gastgeber.length > 0; },
      // Every Gastgeber there is: what the checkboxes start out as
      allHosts: function () { return gastgeber.map(function (cb) { return cb.value; }); },
      // Opens the Gastgeber dialog; false where the book has no Gastgeber
      openDialog: function () {
        if (!dialog) return false;
        dialog.showModal();
        return true;
      },
      // The host's own changes, { present, sprache, genre }, to pass on to the session
      onSessionChange: function (fn) { onSessionChange = fn; }
    };

    render();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
