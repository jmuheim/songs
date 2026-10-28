// Fits each slide's content to the screen: as large as it goes without
// overflowing, between the side chevrons. Every slide that is rendered gets
// fitted, not just the current one: Reveal keeps the neighbours rendered, and
// the overview shows dozens at once. And a slide is fitted again whenever
// anything that decides its size changes — the window, the fonts arriving,
// the chords shown or hidden in the settings, the chevrons coming or going.
//
// A ResizeObserver does the watching. Its callbacks run after layout and
// before paint, so a slide is fitted in the very frame it first appears and
// is never shown at a stale size. That rests on the fit being a
// transform: scale(). A transform leaves the layout alone, so the observer
// sees the content's natural size, and the scaling never sets it off again.
// CSS zoom (what this used before) changes the layout: the text re-wraps at
// another width than was measured, and the observer would fire once more.
//
// Until its first fit, a slide's content stays invisible (night.css), so a
// reload shows a blank slide for a moment rather than one at the wrong size.
(function () {
  var FITTED = 'section.deck-title-slide > .slide-content, ' +
               'section.level1 > .slide-content, section.level2 > .slide-content';

  // Reveal's chevrons (controlsLayout: 'edges') sit over the middle of each
  // screen edge; fit the content between them, not under them — at full width,
  // more than half the slides ran their lyrics into a side chevron, and a slide
  // filling the height ran its last line into the bottom one. The gutter on
  // each axis is as deep as the chevrons reach in from the edge. Where they
  // are hidden (a touch screen, a live-scroll session) they measure 0 and the
  // content gets the whole screen. Layout offsets, not getBoundingClientRect:
  // Reveal slides a chevron in and out with a transform, which would skew a
  // measurement taken mid-way.
  function chevronGutters() {
    var controls = document.querySelector('.reveal .controls');
    var right = controls && controls.querySelector('.navigate-right');
    if (!right || !right.offsetWidth) return { x: 0, y: 0 };
    var up = controls.querySelector('.navigate-up'), down = controls.querySelector('.navigate-down');
    return {
      x: controls.clientWidth - right.offsetLeft,
      y: Math.max(up.offsetTop + up.offsetHeight, controls.clientHeight - down.offsetTop)
    };
  }

  // Measure all, then scale all: a write between two reads would make the
  // browser recompute styles before the second one.
  function fit(contents) {
    var gutters = chevronGutters();
    var availW = window.innerWidth - 2 * gutters.x;
    var availH = window.innerHeight - 2 * gutters.y;
    var sizes = contents.map(function (c) { return [c.scrollWidth, c.scrollHeight]; });
    contents.forEach(function (content, i) {
      var w = sizes[i][0], h = sizes[i][1];
      if (!w || !h) return; // not rendered: fitted once Reveal shows it
      content.style.transform = 'scale(' + Math.min(availW / w, availH / h) + ')';
      content.setAttribute('data-fitted', '');
    });
  }

  var all = Array.prototype.slice.call(document.querySelectorAll(FITTED));
  var chevron = null;

  // A slide's own entry means its content changed size: fit that one. The
  // page's or the chevron's means the room to fit into changed: fit them all.
  var observer = new ResizeObserver(function (entries) {
    var roomChanged = entries.some(function (e) {
      return e.target === document.documentElement || e.target === chevron;
    });
    fit(roomChanged ? all : entries.map(function (e) { return e.target; }));
  });

  function watchChevron() {
    var next = document.querySelector('.reveal .controls .navigate-right');
    if (!next || next === chevron) return;
    chevron = next;
    observer.observe(chevron);
  }

  all.forEach(function (content) { observer.observe(content); });
  observer.observe(document.documentElement);
  watchChevron();
  if (window.Reveal) Reveal.on('ready', watchChevron); // in case Reveal builds its controls later
})();
