// Filters the table of contents by tag. The build (inject_toc_filter in
// lib/build_helpers.rb) renders the <fieldset id="toc-filter"> (one <select>
// per category — Sprache, Genre — plus a Reset button) and a data-sprache /
// data-genre attribute on each song's <li>; this only wires the selects. The
// two categories combine with AND (a song must match the selected value in
// each category that has one); an untagged entry (incl. the Introduction)
// hides while any filter is active. Reset clears both selects. The selects
// and the button are real form controls, so the keyboardCondition in
// body-controls.html already keeps their keys from reaching Reveal. The
// selection is local to this client and not synced over multiplex.
(function () {
  function init() {
    var bar = document.getElementById('toc-filter');
    if (!bar) return;

    var sprache = document.getElementById('toc-filter-sprache');
    var genre   = document.getElementById('toc-filter-genre');
    var reset   = document.getElementById('toc-filter-reset');
    var items   = Array.prototype.slice.call(document.querySelectorAll('#TOC nav li'));

    function matches(li, select, attr) {
      if (!select || !select.value) return true; // that category has no filter active
      var values = (li.getAttribute(attr) || '').split(',');
      return values.indexOf(select.value) !== -1;
    }

    function render() {
      items.forEach(function (li) {
        var shown = matches(li, sprache, 'data-sprache') && matches(li, genre, 'data-genre');
        li.classList.toggle('toc-hidden', !shown);
      });
    }

    [sprache, genre].forEach(function (select) {
      if (select) select.addEventListener('change', render);
    });

    if (reset) {
      reset.addEventListener('click', function () {
        if (sprache) sprache.value = '';
        if (genre) genre.value = '';
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
