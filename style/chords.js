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
    if (songChord) return songChord;
    if (DEFAULT_CHORDS[chordName]) return { tab: DEFAULT_CHORDS[chordName] };
    return null;
  }

  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text != null) node.textContent = text;
    return node;
  }

  // Renders the same "|E A D G B e|" tab look already used in songs' own
  // Instructions legends, so the tooltip reads as the same notation, not a
  // separate UI widget.
  function buildTooltipContent(chordName, result) {
    var pre = el('pre');
    var code = el('code');
    pre.appendChild(code);

    if (!result) {
      code.textContent = chordName + ': kein Griffbild hinterlegt';
    } else if (result.text) {
      code.textContent = chordName + ': ' + result.text;
    } else {
      var pad = new Array(chordName.length + 2).join(' ');
      var lines = [
        pad + '|E A D G B e|',
        pad + '|-----------|',
        chordName + ' |' + result.tab + '|'
      ];
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
    tooltip.appendChild(tooltipInner);
    document.body.appendChild(tooltip);
    document.body.classList.add('chords-clickable');

    var MARGIN = 12;
    var activeChord = null;

    function hideTooltip() {
      tooltip.classList.remove('visible');
      if (activeChord) activeChord.classList.remove('chord-active');
      activeChord = null;
    }

    function positionTooltip(anchor) {
      var rect = anchor.getBoundingClientRect();
      var tw = tooltip.offsetWidth;
      var th = tooltip.offsetHeight;

      var left = rect.left;
      if (left + tw > window.innerWidth - MARGIN) left = window.innerWidth - tw - MARGIN;
      if (left < MARGIN) left = MARGIN;

      var top = rect.bottom + MARGIN;
      if (top + th > window.innerHeight - MARGIN) top = rect.top - th - MARGIN;
      if (top < MARGIN) top = MARGIN;

      tooltip.style.left = left + 'px';
      tooltip.style.top = top + 'px';
    }

    // The chord's own rendered font size already reflects the slide's
    // auto-fit zoom (see slide-zoom.js), which is calibrated to fill the
    // screen with THAT slide's content — on a sparse slide (few lines, small
    // viewport) that zoom factor can be huge. Matching it 1:1 is a good
    // starting point but can make the (much longer) tooltip text overflow
    // the viewport, so shrink it back down until it actually fits.
    function fitFontSize(chordEl) {
      var desired = parseFloat(getComputedStyle(chordEl).fontSize);
      tooltipInner.style.fontSize = desired + 'px';

      var maxW = window.innerWidth - MARGIN * 2;
      var maxH = window.innerHeight - MARGIN * 2;
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
      if (chordEl && /^[a-gx]$/.test(chordEl.className)) {
        e.preventDefault();
        e.stopPropagation();
        if (activeChord === chordEl) { hideTooltip(); return; }
        if (activeChord) activeChord.classList.remove('chord-active');
        activeChord = chordEl;
        chordEl.classList.add('chord-active');
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
  });
})();
