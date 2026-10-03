(function () {
  // Fallback fingerings (E A D G B e; x = muted, 0 = open) for chords that
  // don't have an author-curated voicing in the song's own "Instructions" legend.
  var DEFAULT_CHORDS = {
    'A':      'x 0 2 2 2 0',
    'A7':     'x 0 2 0 2 0',
    'Am':     'x 0 2 2 1 0',
    'Am7':    'x 0 2 0 1 0',
    'B':      'x 2 4 4 4 2',
    'B7':     'x 2 1 2 0 2',
    'Bb':     'x 1 3 3 3 1',
    'Bdim':   'x 2 3 4 3 x',
    'Bm':     'x 2 4 4 3 2',
    'C':      'x 3 2 0 1 0',
    'C7':     'x 3 2 3 1 0',
    'D':      'x x 0 2 3 2',
    'D+':     'x x 0 3 3 2',
    'D7':     'x x 0 2 1 2',
    'D7sus4': 'x x 0 2 1 3',
    'Dm':     'x x 0 2 3 1',
    'Dm6':    'x x 0 2 0 1',
    'Dm7':    'x x 0 2 1 1',
    'Dsus2':  'x x 0 2 3 0',
    'E':      '0 2 2 1 0 0',
    'E7':     '0 2 0 1 0 0',
    'Eb':     'x 6 8 8 8 6',
    'Em':     '0 2 2 0 0 0',
    'Em7':    '0 2 0 0 0 0',
    'Esus4':  '0 2 2 2 0 0',
    'F':      '1 3 3 2 1 1',
    'F#':     '2 4 4 3 2 2',
    'F#m':    '2 4 4 2 2 2',
    'FM7':    'x x 3 2 1 0',
    'Fadd9':  'x x 3 2 1 3',
    'G':      '3 2 0 0 0 3',
    'G#m':    '4 6 6 4 4 4',
    'G5':     '3 5 x x x x',
    'G6':     '3 2 0 0 0 0',
    'G7':     '3 2 0 0 0 1',
    'G7sus4': '3 3 0 0 1 1',
    'Gm':     '3 5 5 3 3 3'
  };

  // Ukulele fingerings (G C E A, standard re-entrant soprano tuning) for the
  // same chord names as DEFAULT_CHORDS above. Songs only ever document their
  // own voicings for guitar (see parseSongChords), so this dictionary is the
  // sole ukulele source — there is no per-song override to prefer.
  // Source: https://ukulele-chords.com (cross-checked against the raw page,
  // not an AI summary of it).
  var UKULELE_CHORDS = {
    'A':      '2 1 0 0',
    'A7':     '0 1 0 0',
    'Am':     '2 0 0 0',
    'Am7':    '0 0 0 0',
    'B':      '4 3 2 2',
    'B7':     '2 3 2 2',
    'Bb':     '3 2 1 1',
    'Bdim':   '4 2 1 2',
    'Bm':     '4 2 2 2',
    'C':      '0 0 0 3',
    'C7':     '0 0 0 1',
    'D':      '2 2 2 0',
    'D+':     '3 2 2 1',
    'D7':     '2 2 2 3',
    'D7sus4': '2 2 3 3',
    'Dm':     '2 2 1 0',
    'Dm6':    '2 2 1 2',
    'Dm7':    '2 2 1 3',
    'Dsus2':  '2 2 0 0',
    'E':      '1 4 0 2',
    'E7':     '1 2 0 2',
    'Eb':     '3 3 3 1',
    'Em':     '0 4 3 2',
    'Em7':    '0 2 0 2',
    'Esus4':  '4 4 0 0',
    'F':      '2 0 1 0',
    'F#':     '3 1 2 1',
    'F#m':    '2 1 2 0',
    'FM7':    '2 4 1 3',
    'Fadd9':  '0 0 1 0',
    'G':      '0 2 3 2',
    'G#m':    '4 3 4 2',
    'G5':     'x 2 3 5',
    'G6':     '0 2 0 2',
    'G7':     '0 2 1 2',
    'G7sus4': '0 2 1 3',
    'Gm':     '0 2 3 1'
  };

  var SPECIAL_TEXT = {
    'X': 'Stop playing / percussive hit — no chord'
  };

  // Parses "ChordName |fret fret fret fret fret fret| optional hint" lines
  // out of a song's own <pre><code> legend blocks (see e.g. "Instructions"
  // sections), so the tooltip reuses the exact voicing the author picked
  // for that song instead of a generic default.
  function parseSongChords(songSection) {
    var map = {};
    var prevBase = null;
    if (!songSection) return map;
    var blocks = songSection.querySelectorAll('pre code');
    for (var b = 0; b < blocks.length; b++) {
      var lines = blocks[b].textContent.split('\n');
      for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(/^\s*([^|]*)\|([^|]+)\|\s*(.*)$/);
        if (!m) continue;
        var name = m[1].trim();
        var fretsRaw = m[2].trim();
        var note = m[3].trim();
        var tokens = fretsRaw.split(/[\s=]+/).filter(Boolean);
        var valid = tokens.length === 6 && tokens.every(function (t) { return /^[xX]$|^\d{1,2}$/.test(t); });
        if (!valid) continue;
        if (name.charAt(0) === '(' && prevBase) {
          name = prevBase + name;
        } else if (name) {
          prevBase = name.replace(/\(.*\)$/, '');
        }
        if (!name) continue;
        map[name] = { tab: fretsRaw, note: note || null };
      }
    }
    return map;
  }

  function lookupChord(chordName, songSection) {
    if (SPECIAL_TEXT[chordName]) return { text: SPECIAL_TEXT[chordName] };
    var songChord = parseSongChords(songSection)[chordName];
    var result = songChord || (DEFAULT_CHORDS[chordName] ? { tab: DEFAULT_CHORDS[chordName] } : null);
    if (!result) return null;
    if (UKULELE_CHORDS[chordName]) result.ukulele = UKULELE_CHORDS[chordName];
    return result;
  }

  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text != null) node.textContent = text;
    return node;
  }

  // Spaces, not a literal count: Array(n + 1).join(' ') is the idiom this
  // file already uses to get n spaces without a trailing one.
  function spaces(n) { return new Array(n + 1).join(' '); }

  function padEnd(str, len) {
    return str.length < len ? str + spaces(len - str.length) : str;
  }

  // The guitar block carries the chord name, so its own rows (including the
  // "Guitar:" label) are indented by that name's width — the same pad the
  // chord row needs anyway to line its "Name |" up under the header's
  // opening pipe.
  function guitarBlock(chordName, tab) {
    var pad = spaces(chordName.length + 1);
    return [
      pad + 'Guitar:',
      pad + '|E A D G B e|',
      pad + '|-----------|',
      chordName + ' |' + tab + '|'
    ];
  }

  // The ukulele block never repeats the chord name — that'd be redundant
  // next to the guitar column that already carries it — so its four rows
  // are already each other's width and need no pad of their own.
  function ukuleleBlock(tab) {
    return ['Ukulele:', '|G C E A|', '|-------|', '|' + tab + '|'];
  }

  // Columns sit this many spaces apart — enough to read as two separate
  // blocks, not so wide the tooltip outgrows a landscape phone.
  var COLUMN_GAP = 2;

  function buildTooltipContent(chordName, result) {
    var pre = el('pre');
    var code = el('code');
    pre.appendChild(code);

    if (!result) {
      code.textContent = chordName + ': kein Griffbild hinterlegt';
    } else if (result.text) {
      code.textContent = chordName + ': ' + result.text;
    } else {
      var guitarLines = guitarBlock(chordName, result.tab);
      var lines;
      if (result.ukulele) {
        var ukuleleLines = ukuleleBlock(result.ukulele);
        var colWidth = Math.max.apply(null, guitarLines.map(function (l) { return l.length; })) + COLUMN_GAP;
        lines = guitarLines.map(function (l, i) { return padEnd(l, colWidth) + ukuleleLines[i]; });
      } else {
        lines = guitarLines;
      }
      // The note comes from a song's own Instructions legend (see
      // parseSongChords) and describes that guitar voicing specifically, so
      // it runs full-width below both columns rather than inside either.
      if (result.note) lines.push('', result.note);
      code.textContent = lines.join('\n');
    }

    var frag = document.createDocumentFragment();
    frag.appendChild(pre);
    return frag;
  }

  window.addEventListener('load', function () {
    // The outer element handles fixed positioning in plain (unzoomed) viewport
    // pixels; the inner one gets the CSS `zoom` applied. Zooming the outer
    // element directly would also scale its own left/top offsets, throwing
    // off the positioning math below.
    var tooltip = el('div');
    tooltip.id = 'chord-tooltip';
    tooltip.setAttribute('role', 'tooltip');
    var tooltipInner = el('div', 'chord-tooltip-inner');
    // Read out when it appears: the focus stays on the chord.
    tooltipInner.setAttribute('aria-live', 'polite');
    tooltip.appendChild(tooltipInner);
    document.body.appendChild(tooltip);
    document.body.classList.add('chords-clickable');

    var MARGIN = 12;
    var activeChord = null;

    function isChord(node) {
      return node && node.matches && node.matches('.reveal section code[class]') && /^[a-gx]$/.test(node.className.split(' ')[0]);
    }

    // Each chord is a button, reachable with Tab and opened with Enter or
    // Space like one. Space is Reveal's page turn: keyboardCondition in
    // body-controls.html leaves it to a chord focused from the keyboard.
    Array.prototype.forEach.call(document.querySelectorAll('.reveal section code[class]'), function (chordEl) {
      if (!isChord(chordEl)) return;
      chordEl.setAttribute('role', 'button');
      chordEl.setAttribute('tabindex', '0');
      chordEl.setAttribute('aria-expanded', 'false');
      chordEl.setAttribute('aria-controls', 'chord-tooltip');
    });

    // On window, so it runs after Reveal's handler on the document: a key
    // Reveal acted on (defaultPrevented), or one after which Reveal moved the
    // focus away, is not the chord's.
    window.addEventListener('keydown', function (e) {
      var chordEl = document.activeElement;
      if (e.defaultPrevented || (e.key !== 'Enter' && e.key !== ' ') || !isChord(chordEl) || e.target !== chordEl) return;
      e.preventDefault();
      chordEl.click();
    });

    function hideTooltip() {
      tooltip.classList.remove('visible');
      if (activeChord) {
        activeChord.classList.remove('chord-active');
        activeChord.setAttribute('aria-expanded', 'false');
      }
      activeChord = null;
    }

    // Mobile Safari's address/tab bar means `window.innerWidth/innerHeight`
    // (the layout viewport) can be bigger than what's actually visible on
    // screen (the visual viewport) — `getBoundingClientRect()` coordinates
    // are layout-viewport-relative, same as our `position: fixed` tooltip,
    // so no offset translation is needed there, but clamping against
    // `window.innerHeight` alone can place the tooltip in a region that's
    // technically in the DOM layout but currently hidden behind Safari's
    // chrome. `visualViewport` reports the truly-visible area.
    function viewportSize() {
      var vv = window.visualViewport;
      return vv ? { width: vv.width, height: vv.height } : { width: window.innerWidth, height: window.innerHeight };
    }

    function positionTooltip(anchor) {
      var rect = anchor.getBoundingClientRect();
      var vp = viewportSize();
      var tw = tooltip.offsetWidth;
      var th = tooltip.offsetHeight;

      var left = rect.left;
      if (left + tw > vp.width - MARGIN) left = vp.width - tw - MARGIN;
      if (left < MARGIN) left = MARGIN;

      var top = rect.bottom + MARGIN;
      if (top + th > vp.height - MARGIN) top = rect.top - th - MARGIN;
      if (top < MARGIN) top = MARGIN;

      tooltip.style.left = left + 'px';
      tooltip.style.top = top + 'px';
    }

    // The chord's own rendered font size already reflects the slide's
    // auto-fit zoom (see slide-zoom.js), which is calibrated to fill the
    // screen with THAT slide's content — on a sparse slide (few lines, small
    // viewport) that zoom factor can be huge. Matching it 1:1 is a good
    // starting point but can make the (much longer, ~18-character-wide) tab
    // text overflow, especially on a narrow phone. Shrink it back down to a
    // fraction of the viewport — not just barely-fits-full-screen — so it
    // reads as a compact tooltip next to the chord rather than a full-screen
    // panel, and so there's still room to position it near the chord.
    function fitFontSize(chordEl) {
      var desired = parseFloat(getComputedStyle(chordEl).fontSize);
      tooltipInner.style.fontSize = desired + 'px';

      var vp = viewportSize();
      var maxW = vp.width * 0.7 - MARGIN * 2;
      var maxH = vp.height * 0.45 - MARGIN * 2;
      var scale = Math.min(1, maxW / tooltip.offsetWidth, maxH / tooltip.offsetHeight);
      if (scale < 1) tooltipInner.style.fontSize = (desired * scale) + 'px';
    }

    function showTooltip(chordEl) {
      var chordName = chordEl.textContent.trim();
      var songSection = chordEl.closest('section');
      songSection = songSection ? songSection.parentElement : null;

      tooltipInner.innerHTML = '';
      tooltipInner.appendChild(buildTooltipContent(chordName, lookupChord(chordName, songSection)));

      tooltip.classList.add('visible');
      fitFontSize(chordEl);
      positionTooltip(chordEl);
    }

    document.addEventListener('click', function (e) {
      var chordEl = e.target.closest && e.target.closest('.reveal section code[class]');
      if (isChord(chordEl)) {
        e.preventDefault();
        e.stopPropagation();
        if (activeChord === chordEl) { hideTooltip(); return; }
        if (activeChord) {
          activeChord.classList.remove('chord-active');
          activeChord.setAttribute('aria-expanded', 'false');
        }
        activeChord = chordEl;
        chordEl.classList.add('chord-active');
        chordEl.setAttribute('aria-expanded', 'true');
        showTooltip(chordEl);
        return;
      }
      if (!tooltip.contains(e.target)) hideTooltip();
    });

    // Capture phase: intercept Escape before Reveal's own document-level
    // handler sees it (it uses Escape to toggle overview mode).
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && tooltip.classList.contains('visible')) {
        e.stopPropagation();
        e.preventDefault();
        hideTooltip();
      }
    }, true);

    if (window.Reveal) Reveal.on('slidechanged', hideTooltip);

    // Close on any viewport change (orientation flip, Safari's toolbar
    // show/hide, browser resize) rather than trying to reposition/rescale a
    // stale tooltip — its position and font size were computed for the old
    // viewport and slide-zoom.js will itself recompute the slide's zoom.
    window.addEventListener('resize', hideTooltip);
    window.addEventListener('orientationchange', hideTooltip);
    if (window.visualViewport) window.visualViewport.addEventListener('resize', hideTooltip);
  });
})();
