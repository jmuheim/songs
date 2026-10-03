require 'capybara/rspec'

# Exercises style/chords.js: clicking an inline chord badge opens a tooltip
# showing how to grip it, in the same "|E A D G B e|" tab notation used in the
# songs' own Instructions legends, with a "|G C E A|" ukulele column from the
# built-in UKULELE_CHORDS dictionary beside it (side by side, not stacked —
# there's more horizontal than vertical room in a landscape slide).
#
# Fixture leverage: "Across the universe" ships an Instructions legend with
#   F#m    |2=4=4=2=2=2|   (barre notation, "=")
#   (barré)|2 4 4 2 2 2|   (a "(…)" continuation line: names F#m(barré))
# while the built-in fallback dictionary has plain "2 4 4 2 2 2" for F#m — so a
# single F#m click proves the song's own voicing wins over the generic default,
# and a D click (absent from the legend) proves the fallback path. Since songs
# only ever document guitar voicings, F#m's ukulele column comes from the
# dictionary even though its guitar tab came from the legend — proving the two
# lookups are independent. Its Intro is a chord-only progression —
# [F#m(barré)] [X] [Baug] [A7sus4] — that reaches the three branches the verse
# can't: the "(…)" continuation name (which has no ukulele entry under that
# composed name, so no ukulele column shows, and the layout falls back to a
# single guitar-only column), the [X] special text, and the "no fingering on
# file" message for a chord in neither source.
RSpec.describe 'chord tooltips (style/chords.js)', :js, type: :feature do
  before(:all) do
    FixtureBuilder.build!
    FileServer.start
    Capybara.app_host = FileServer.url
  end

  # Across the universe → Verse 1 (has D, F#m; its stack also holds the legend)
  VERSE_ID = 'verse-1-1'.freeze

  before do
    visit FixtureBuilder::URL_PATH
    wait_for_reveal
  end

  def go_to(section_id)
    page.evaluate_script(<<~JS)
      (function () {
        var i = Reveal.getIndices(document.getElementById('#{section_id}'));
        Reveal.slide(i.h, i.v);
      })();
    JS
    wait_for_js("document.querySelector('section.present') && document.querySelector('section.present').id === '#{section_id}'")
  end

  # The Intro's section id is Pandoc-generated and depends on global heading
  # order, so navigate to it by the one chord only it carries: [X].
  def go_to_intro
    page.execute_script(<<~JS)
      (function () {
        var codes = document.querySelectorAll('.reveal code.x');
        for (var i = 0; i < codes.length; i++) {
          if (codes[i].textContent.trim() === 'X') {
            var idx = Reveal.getIndices(codes[i].closest('section.slide'));
            Reveal.slide(idx.h, idx.v);
            return;
          }
        }
      })();
    JS
    wait_for_js("!!document.querySelector('section.present code.x')")
  end

  def tooltip_tab
    page.evaluate_script("document.querySelector('#chord-tooltip .chord-tooltip-inner code').textContent")
  end

  describe 'verse chords' do
    before { go_to(VERSE_ID) }

    def click_chord(css, text)
      first("##{VERSE_ID} #{css}", text: text, exact_text: true).click
    end

    it "shows the fingering tab and prefers the song's own legend voicing over the fallback dictionary" do
      # Legend-documented chord: barre voicing straight from the Instructions block.
      # Pinned in full, not just `include` — the point of this layout is that
      # the two columns line up, and a loose substring check can't catch a
      # misaligned pipe or a wrong gap between them.
      click_chord('code.f', 'F#m')
      expect(page).to have_visible('#chord-tooltip')
      expect(page).to have_css('code.f.chord-active', text: 'F#m')
      # Guitar column: the legend's barre voicing ("2=4=4=2=2=2"), not the
      # plain "2 4 4 2 2 2" fallback. Ukulele column (no chord name of its
      # own — the guitar column already carries it): no per-song legend
      # exists for ukulele, so it's always the dictionary's "2 1 2 0" — even
      # here, where the guitar tab beside it came from the legend.
      expect(tooltip_tab).to eq(
        "    Guitar:        Ukulele:\n" \
        "    |E A D G B e|  |G C E A|\n" \
        "    |-----------|  |-------|\n" \
        "F#m |2=4=4=2=2=2|  |2 1 2 0|"
      )

      # Chord absent from the legend: falls back to the built-in dictionary
      # for both columns, and switching chords moves the active marker.
      click_chord('code.d', 'D')
      expect(page).to have_css('code.d.chord-active', text: 'D')
      expect(page).to have_no_css('code.f.chord-active')
      expect(tooltip_tab).to eq(
        "  Guitar:        Ukulele:\n" \
        "  |E A D G B e|  |G C E A|\n" \
        "  |-----------|  |-------|\n" \
        "D |x x 0 2 3 2|  |2 2 2 0|"
      )

      # From the keyboard a chord is a button: Tab reaches it, Enter opens it,
      # Space closes it again — and does not turn the page
      find("##{VERSE_ID} h2").click
      expect(page).not_to have_visible('#chord-tooltip')
      chord_focused = "document.activeElement.matches('code[role=\"button\"]')"
      30.times { break if page.evaluate_script(chord_focused); press(:tab) }
      expect(page.evaluate_script(chord_focused)).to be true
      # Its ring is the theme's white, not the chord's black text colour, and a
      # chord under the mouse wears the same one.
      ring = "(function (el) { var s = getComputedStyle(el); return s.outlineStyle + ' ' + s.outlineColor; })"
      focus_ring = page.evaluate_script("#{ring}(document.activeElement)")
      expect(focus_ring).to eq('solid rgb(255, 255, 255)')
      all("##{VERSE_ID} code[role=\"button\"]").last.hover
      expect(page.evaluate_script("#{ring}(document.querySelector('##{VERSE_ID} code[role=\"button\"]:hover'))")).to eq(focus_ring)
      press(:enter)
      expect(page).to have_visible('#chord-tooltip')
      expect(page.evaluate_script("document.activeElement.getAttribute('aria-expanded')")).to eq('true')
      press(:space)
      expect(page).not_to have_visible('#chord-tooltip')
      expect(page).to have_css('section.present#' + VERSE_ID)
    end

    it 'closes on re-click, outside click, Escape (without toggling Reveal overview), and slide change' do
      # Re-clicking the same chord toggles it closed.
      click_chord('code.d', 'D')
      expect(page).to have_visible('#chord-tooltip')
      click_chord('code.d', 'D')
      expect(page).not_to have_visible('#chord-tooltip')

      # Clicking a non-chord element dismisses it.
      click_chord('code.d', 'D')
      expect(page).to have_visible('#chord-tooltip')
      find("##{VERSE_ID} h2").click
      expect(page).not_to have_visible('#chord-tooltip')

      # Escape closes the tooltip and is swallowed before Reveal's overview toggle.
      click_chord('code.d', 'D')
      expect(page).to have_visible('#chord-tooltip')
      find('body').send_keys(:escape)
      expect(page).not_to have_visible('#chord-tooltip')
      expect(page.evaluate_script('Reveal.isOverview()')).to be false

      # A slide change dismisses any open tooltip rather than leaving it stranded.
      click_chord('code.d', 'D')
      expect(page).to have_visible('#chord-tooltip')
      page.evaluate_script('Reveal.next()')
      expect(page).not_to have_visible('#chord-tooltip')
    end
  end

  describe 'special and undocumented chords' do
    before { go_to_intro }

    def click_intro_chord(css, text)
      find('section.present ' + css, text: text, exact_text: true).click
    end

    it 'shows the [X] percussive hint text instead of a fret diagram' do
      click_intro_chord('code.x', 'X')
      expect(page).to have_visible('#chord-tooltip')
      expect(tooltip_tab).to eq('X: Stop playing / percussive hit — no chord')
    end

    it 'says so when a chord is in neither the legend nor the fallback dictionary' do
      click_intro_chord('code.b', 'Baug')
      expect(page).to have_visible('#chord-tooltip')
      expect(tooltip_tab).to eq('Baug: kein Griffbild hinterlegt')
    end

    it 'assembles a chord name from a "(…)" continuation line in the legend' do
      # F#m(barré) exists only because the legend's "(barré)" line inherits the
      # base name of the F#m line above it; both its voicing and its note show.
      # That composed name has no entry of its own in the ukulele dictionary
      # (only plain "F#m" does), so the layout falls back to a single
      # guitar-only column instead of the usual two side by side.
      click_intro_chord('code.f', 'F#m(barré)')
      expect(page).to have_visible('#chord-tooltip')
      expect(tooltip_tab).to eq(
        "           Guitar:\n" \
        "           |E A D G B e|\n" \
        "           |-----------|\n" \
        "F#m(barré) |2 4 4 2 2 2|\n" \
        "\n" \
        "open-position shape"
      )
    end
  end
end
