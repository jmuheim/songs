require 'capybara/rspec'

# Exercises style/chords.js: clicking an inline chord badge opens a tooltip
# showing how to grip it, in the same "|E A D G B e|" tab notation used in the
# songs' own Instructions legends.
#
# Fixture leverage: "Across the universe" ships an Instructions legend with
#   F#m    |2=4=4=2=2=2|   (barre notation, "=")
#   (barré)|2 4 4 2 2 2|   (a "(…)" continuation line: names F#m(barré))
# while the built-in fallback dictionary has plain "2 4 4 2 2 2" for F#m — so a
# single F#m click proves the song's own voicing wins over the generic default,
# and a D click (absent from the legend) proves the fallback path. Its Intro is
# a chord-only progression — [F#m(barré)] [X] [Baug] [A7sus4] — that reaches the
# three branches the verse can't: the "(…)" continuation name, the [X] special
# text, and the "no fingering on file" message for a chord in neither source.
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
      click_chord('code.f', 'F#m')
      expect(page).to have_visible('#chord-tooltip')
      expect(page).to have_css('code.f.chord-active', text: 'F#m')
      tab = tooltip_tab
      expect(tab).to include('|E A D G B e|')
      expect(tab).to include('F#m |2=4=4=2=2=2|') # legend wins...
      expect(tab).not_to include('2 4 4 2 2 2')   # ...over the plain fallback

      # Chord absent from the legend: falls back to the built-in dictionary, and
      # switching chords moves the active marker.
      click_chord('code.d', 'D')
      expect(page).to have_css('code.d.chord-active', text: 'D')
      expect(page).to have_no_css('code.f.chord-active')
      expect(tooltip_tab).to include('D |x x 0 2 3 2|')
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
      click_intro_chord('code.f', 'F#m(barré)')
      expect(page).to have_visible('#chord-tooltip')
      tab = tooltip_tab
      expect(tab).to include('F#m(barré) |2 4 4 2 2 2|')
      expect(tab).to include('open-position shape')
    end
  end
end
