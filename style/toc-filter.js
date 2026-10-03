// Filters the table of contents by tag. The build (inject_toc_filter in
// lib/build_helpers.rb) renders the chip bar (#toc-filter: one .toc-tag[data-tag]
// button per tag, plus the „Alle" button) and a data-tags attribute on each song's
// <li>; this only wires the clicks. Several tags combine with OR — a song shows if
// it carries any selected tag. „Alle" clears the selection. Chips are real buttons,
// so the keyboardCondition in body-controls.html already keeps Space from paging the
// deck. The selection is local to this client and not synced over multiplex.
(function () {
  function init() {
    var bar = document.getElementById('toc-filter');
    if (!bar) return;

    var chips   = Array.prototype.slice.call(bar.querySelectorAll('.toc-tag[data-tag]'));
    var allChip = bar.querySelector('.toc-tag-all');
    var items   = Array.prototype.slice.call(document.querySelectorAll('#TOC nav li'));
    var active  = {}; // selected tag -> true

    function render() {
      var any = Object.keys(active).length > 0;

      items.forEach(function (li) {
        if (!any) { li.classList.remove('toc-hidden'); return; }
        var tags = (li.getAttribute('data-tags') || '').split(',');
        var match = tags.some(function (tag) { return active[tag]; });
        li.classList.toggle('toc-hidden', !match); // untagged items hide while filtering
      });

      chips.forEach(function (chip) {
        chip.setAttribute('aria-pressed', active[chip.getAttribute('data-tag')] ? 'true' : 'false');
      });
      if (allChip) allChip.setAttribute('aria-pressed', any ? 'false' : 'true');
    }

    chips.forEach(function (chip) {
      chip.addEventListener('click', function () {
        var tag = chip.getAttribute('data-tag');
        if (active[tag]) delete active[tag]; else active[tag] = true;
        render();
      });
    });

    if (allChip) {
      allChip.addEventListener('click', function () { active = {}; render(); });
    }

    render();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
