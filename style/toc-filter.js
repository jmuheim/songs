// Filters the table of contents by tag. The build (inject_toc_filter in
// lib/build_helpers.rb) renders the <fieldset id="toc-filter"> (one <select>
// each for Sprache/Genre, a checkbox group for Gastgeber, plus a Reset
// button), a data-sprache / data-genre / data-gastgeber attribute on each
// song's <li>, and a hidden <p id="toc-filter-empty"> for when a filter
// leaves nothing standing; this only wires the controls. Sprache and Genre
// combine with AND (a song must match the selected value in each category
// that has one); Gastgeber's checkboxes combine with OR among themselves (a
// song matches if it names *any* checked host), then AND into the rest — see
// decisions/2026-10-05-gastgeber-filter-uses-checkboxes-not-a-select.md. An
// untagged entry hides while any filter is active. Reset clears every
// control. The selects, checkboxes and the button are real form controls, so
// the keyboardCondition in body-controls.html already keeps their keys from
// reaching Reveal. The selection is local to this client and not synced over
// multiplex.
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

    function matches(li, select, attr) {
      if (!select || !select.value) return true; // that category has no filter active
      var values = (li.getAttribute(attr) || '').split(',');
      return values.indexOf(select.value) !== -1;
    }

    function matchesGastgeber(li) {
      var checked = gastgeber.filter(function (cb) { return cb.checked; }).map(function (cb) { return cb.value; });
      if (!checked.length) return true; // no host checked, no filter active
      var values = (li.getAttribute('data-gastgeber') || '').split(',');
      return checked.some(function (v) { return values.indexOf(v) !== -1; });
    }

    function render() {
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
      checkbox.addEventListener('change', render);
    });

    if (reset) {
      reset.addEventListener('click', function () {
        if (sprache) sprache.value = '';
        if (genre) genre.value = '';
        gastgeber.forEach(function (checkbox) { checkbox.checked = false; });
        render();
      });
    }

    render();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
