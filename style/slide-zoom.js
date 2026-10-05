(function () {
  function fitSlide(section) {
    if (!section) return;
    var isSlide = section.classList.contains('deck-title-slide') || section.classList.contains('level1') || section.classList.contains('level2');
    if (!isSlide) return;
    var content = section.querySelector('.slide-content');
    if (!content) return;

    content.style.zoom = 1;

    var contentW = content.scrollWidth;
    var contentH = content.scrollHeight;
    var availW   = window.innerWidth;
    var availH   = window.innerHeight;

    if (!contentW || !contentH) return;

    content.style.zoom = Math.min(availW / contentW, availH / contentH);
  }

  window.addEventListener('load', function () {
    if (!window.Reveal) return;

    Reveal.on('ready',        function (e) { fitSlide(e.currentSlide); });
    Reveal.on('slidechanged', function (e) { fitSlide(e.currentSlide); });
    window.addEventListener('resize', function () { fitSlide(Reveal.getCurrentSlide()); });

    if (Reveal.isReady()) fitSlide(Reveal.getCurrentSlide());

    // Web fonts (the text fonts and the bundled emoji font) load
    // asynchronously; a slide fitted before they arrive is measured against the
    // fallback font and, on a slow connection, would keep that wrong zoom.
    // Re-fit once the fonts are ready, so the zoom matches the real glyphs on
    // every machine — which is also what makes the exact slide-zoom specs
    // reproducible on the CI runner, where the emoji font loads after Reveal.
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(function () {
        if (window.Reveal && Reveal.isReady()) fitSlide(Reveal.getCurrentSlide());
      });
    }
  });
})();
