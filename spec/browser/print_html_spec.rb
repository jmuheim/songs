require 'capybara/rspec'

RSpec.describe 'print.html', :js, type: :feature do
  before(:all) do
    FixtureBuilder.build!
    FileServer.start
    Capybara.app_host = FileServer.url
  end

  def load_presentation
    visit FixtureBuilder::PRINT_URL_PATH
    wait_for_reveal
  end

  # All reads of one page state, so the page loads once
  it 'has its structure and content, leaves out the Infos sections, and uses the serif (light) theme' do
    load_presentation
    aggregate_failures do
      expect(page.title).to eq('Lieblings-Songs 🔥🎶🌛')

      within(find('section.deck-title-slide[data-background-image*="background.jpg"]', visible: :all)) do
        expect(page).to have_css('h1', text: /Lieblings-Songs 🔥🎶🌛/)
      end

      expect(all('section.level1', visible: :all).size).to eq(song_count + 1) # +1 for Introduction

      expect(page).to have_css('.slide-content', visible: :all)

      expect(page.evaluate_script("Reveal.getTotalSlides()")).to be > song_count

      # Tags, resource links and alternate fingerings are screen-only. have_no_css,
      # not all(): an empty all() returns only after the full default_max_wait_time.
      expect(page).to have_no_css('section[id^="infos-über-das-lied"]', visible: :all)
      expect(all('h2', visible: :all).map { |el| el.text(:all) }).not_to include('Infos über das Lied')

      # The serif theme is the light one
      hex = page.evaluate_script(
        "getComputedStyle(document.documentElement).getPropertyValue('--r-background-color').trim()"
      ).gsub(/[^0-9a-fA-F]/, '')
      r, g, b = hex[0..1].to_i(16), hex[2..3].to_i(16), hex[4..5].to_i(16)
      expect(r + g + b).to be > 400
    end
  end
end
