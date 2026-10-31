// Filters the table of contents by tag. The build (inject_toc_filter in
// lib/build_helpers.rb) renders the <fieldset id="toc-filter"> (one <select>
// each for Sprache/Genre, a „Songs von" button for Gastgeber, plus a Reset
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
// untagged entry hides while any filter is active. Reset clears every
// control. The selects, checkboxes and the button are real form controls, so
// the keyboardCondition in body-controls.html already keeps their keys from
// reaching Reveal. The selection is local to this client and not synced over
// multiplex — except, in a session, the Gastgeber checkboxes (setPresent
// below), which are the host's to set for everyone.
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
    var onPresentChange = null;

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

    [sprache, genre].forEach(function (select) {
      if (select) select.addEventListener('change', render);
    });
    gastgeber.forEach(function (checkbox) {
      checkbox.addEventListener('change', function () {
        render();
        if (inSession && onPresentChange) {
          onPresentChange(checkedHosts());
        }
      });
    });

    if (reset) {
      reset.addEventListener('click', function () {
        if (sprache) sprache.value = '';
        if (genre) genre.value = '';
        // In a session they are whose songs the evening has, not this client's filter
        if (!inSession) gastgeber.forEach(function (checkbox) { checkbox.checked = true; });
        render();
      });
    }

    // The dialog behind the „Songs von" button. Like the others in
    // body-controls.html it keeps its keys from Reveal, which listens on the
    // document, and closes on a click on its backdrop.
    var INFO = {
      own: 'Zeigt die Lieder der angehakten Gastgeber. Wer abgehakt ist, fehlt in der Liste.',
      host: 'Wer ist heute Abend dabei? Alle in der Session sehen nur die Lieder der angehakten Gastgeber.',
      guest: 'Der Gastgeber hat gewählt, wessen Lieder heute Abend gespielt werden können.'
    };
    if (dialog) {
      if (openBtn) openBtn.addEventListener('click', function () { dialog.showModal(); });
      document.getElementById('gastgeber-ok').addEventListener('click', function () { dialog.close(); });
      dialog.addEventListener('keydown', function (e) { e.stopPropagation(); });
      dialog.addEventListener('keypress', function (e) { e.stopPropagation(); });
      dialog.addEventListener('click', function (e) { if (e.target === dialog) dialog.close(); });
    }

    // In a session the Gastgeber checkboxes stop being a filter of one's own:
    // they say whose songs this evening has, so that every list in the
    // session shows only the songs that can be played. The host sets them for
    // everyone — body-controls.html carries them in its heartbeat — and only
    // the host can change them (`editable`); the guests see them ticked, but
    // disabled. `present` null: no session, and the checkboxes are one's own
    // again, all checked.
    window.tocFilter = {
      setPresent: function (present, editable) {
        inSession = !!present;
        gastgeber.forEach(function (checkbox) {
          checkbox.checked = !inSession || present.indexOf(checkbox.value) !== -1;
          checkbox.disabled = inSession && !editable;
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
      // The host's own changes, to pass on to the session
      onPresentChange: function (fn) { onPresentChange = fn; }
    };

    render();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
