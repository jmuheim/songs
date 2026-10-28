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
  var TITLES = 'section.deck-title-slide > .slide-content, section.level1 > .slide-content';
  var FITTED = TITLES + ', section.level2 > .slide-content';

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

  // Rendered pixels per layout pixel: a rect comes out transformed (by the fit
  // already applied, and by Reveal's own scale in the overview), a layout
  // size does not.
  function ratio(content) {
    return content.getBoundingClientRect().width / content.offsetWidth;
  }

  function horizontalPadding(element) {
    var style = getComputedStyle(element);
    return parseFloat(style.paddingLeft) + parseFloat(style.paddingRight);
  }

  // The widest line of text among a content's children (but `except`), in
  // layout pixels, or 0 for none: from a Range's rects, the lines themselves,
  // not their boxes.
  function widestLine(content, except) {
    var range = document.createRange(), left = Infinity, right = -Infinity;
    Array.prototype.forEach.call(content.children, function (child) {
      if (child === except) return;
      range.selectNodeContents(child);
      Array.prototype.forEach.call(range.getClientRects(), function (r) {
        left = Math.min(left, r.left);
        right = Math.max(right, r.right);
      });
    });
    return right > left ? (right - left) / ratio(content) : 0;
  }

  // A title slide (the deck's own, the Introduction's, every song's) holds
  // lines of text and nothing else: a heading, an artist, an author. A title
  // too long for one line wraps, and its box then takes the screen's whole
  // width while its lines fall short of it. Measured by its box, a song's
  // title on an iPad in portrait was never scaled up, its two lines a third
  // short of the edges. So a title slide is measured by its widest line. The
  // lines are centred in the box, so scaling the box about its centre takes
  // them to the edges.
  function naturalWidth(content) {
    if (!content.matches(TITLES)) return content.scrollWidth;
    var widest = widestLine(content);
    return widest ? widest + horizontalPadding(content) : content.scrollWidth;
  }

  // The left and right edges of each word in a heading set on one line, in
  // layout pixels from the first word's left edge.
  function wordEdges(heading, scale) {
    var walker = document.createTreeWalker(heading, NodeFilter.SHOW_TEXT);
    var range = document.createRange(), edges = [], node, word, pattern = /\S+/g;
    while ((node = walker.nextNode())) {
      while ((word = pattern.exec(node.data))) {
        range.setStart(node, word.index);
        range.setEnd(node, word.index + word[0].length);
        var r = range.getBoundingClientRect();
        edges.push([r.left / scale, r.right / scale]);
      }
    }
    return edges.map(function (e) { return [e[0] - edges[0][0], e[1] - edges[0][0]]; });
  }

  // The width of the widest line when the words are split into 1, 2, … lines
  // as evenly as they go: narrowest[n - 1] for n lines. A line from word i to
  // word j is as wide as they stand apart on one line, spaces and kerning
  // included.
  function narrowestSplits(edges) {
    var last = edges.length - 1, rows = [];
    function line(i, j) { return edges[j][1] - edges[i][0]; }
    rows[0] = edges.map(function (e, j) { return line(0, j); });
    for (var n = 1; n <= last; n++) {
      rows[n] = edges.map(function (e, j) {
        var narrowest = Infinity;
        for (var i = n; i <= j; i++) narrowest = Math.min(narrowest, Math.max(rows[n - 1][i - 1], line(i, j)));
        return narrowest;
      });
    }
    return rows.map(function (row) { return row[last]; });
  }

  // A title's heading takes as many lines as make the slide largest. On one
  // line, a long title fills the width of a wide screen and leaves most of
  // its height empty: on an iPad in landscape, three quarters of it. Split
  // over three lines there, „Can't Help Falling in Love" fits 1.77 times as
  // large. But each line makes the slide taller, and on a phone held
  // sideways a second one often costs more than it gains. No one width suits every title on
  // every screen, so each title tries every line count: its words are
  // measured once on a single line, the narrowest split into each number of
  // lines is worked out from where they stand, and the line count whose
  // slide fits largest wins, set as the heading's max-width (shared.css
  // centres the heading and balances its lines). One line is always among
  // them, so no title is smaller for this than unwrapped. Returns the
  // contents whose heading changed width.
  function wrapTitles(contents, availW, availH) {
    var titles = contents.map(function (content) {
      var heading = content.matches(TITLES) && content.offsetWidth && content.querySelector('h1');
      if (!heading) return null;
      return {
        content: content,
        heading: heading,
        // Everything but the heading's own lines, which don't change its height
        others: content.scrollHeight - heading.offsetHeight,
        othersWidth: widestLine(content, heading),
        padding: horizontalPadding(content),
        // Wider than this, a line wraps whatever its max-width
        room: content.parentNode.clientWidth - horizontalPadding(content.parentNode) - horizontalPadding(content)
      };
    }).filter(Boolean);

    titles.forEach(function (t) {
      t.before = t.heading.style.maxWidth;
      t.heading.style.whiteSpace = 'nowrap';
      t.heading.style.maxWidth = 'none';
    });
    titles.forEach(function (t) {
      t.edges = wordEdges(t.heading, ratio(t.content));
      t.lineHeight = t.heading.offsetHeight;
    });

    return titles.filter(function (t) {
      t.heading.style.whiteSpace = '';
      var splits = t.edges.length ? narrowestSplits(t.edges) : [0], best = 0, lines = 1;
      splits.forEach(function (widest, i) {
        // A split that doesn't fit wraps further on its own; the last one
        // (a word to a line) is all there is for a word wider than the room
        if (widest > t.room && i < splits.length - 1) return;
        var scale = Math.min(availW / (Math.max(widest, t.othersWidth) + t.padding),
                             availH / (t.others + (i + 1) * t.lineHeight));
        if (scale > best) { best = scale; lines = i + 1; }
      });
      // The pixel over keeps the line from wrapping on a rounding error
      t.heading.style.maxWidth = lines > 1 ? Math.ceil(splits[lines - 1]) + 1 + 'px' : '';
      return t.heading.style.maxWidth !== t.before;
    }).map(function (t) { return t.content; });
  }

  // Measure all, then scale all: a write between two reads would make the
  // browser recompute styles before the second one.
  function fit(contents) {
    var gutters = chevronGutters();
    var availW = window.innerWidth - 2 * gutters.x;
    var availH = window.innerHeight - 2 * gutters.y;
    var rewrapped = wrapTitles(contents, availW, availH);
    var sizes = contents.map(function (c) { return [naturalWidth(c), c.scrollHeight]; });
    contents.forEach(function (content, i) {
      var w = sizes[i][0], h = sizes[i][1];
      if (!w || !h) return; // not rendered: fitted once Reveal shows it
      content.style.transform = 'scale(' + Math.min(availW / w, availH / h) + ')';
      content.setAttribute('data-fitted', '');
    });
    // A rewrapped title has changed size since the observer reported it, and
    // the observer would report it again in this same frame, where it can't:
    // a "ResizeObserver loop" error. It's fitted at its new size already, so
    // it's let go and observed afresh from the next frame, whose first report
    // then finds nothing left to change.
    rewrapped.forEach(function (content) {
      observer.unobserve(content);
      requestAnimationFrame(function () { observer.observe(content); });
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
