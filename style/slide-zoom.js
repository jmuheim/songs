(function () {
  function fitSlide(section) {
    if (!section || !section.classList.contains('level2')) return;
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

    window.addEventListener('resize', function () {
      fitSlide(Reveal.getCurrentSlide());
    });
  });
})();
