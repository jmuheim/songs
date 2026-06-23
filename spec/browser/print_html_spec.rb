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

  before { load_presentation }

  it 'has correct DOM structure and content' do
    expect(page.title).to eq('Lieblings-Songs 🔥🎶🌛')

    within(find('#title-slide[data-background-image*="background.jpg"]', visible: :all)) do
      expect(page).to have_css('h1', text: /Lieblings-Songs 🔥🎶🌛/)
    end

    expect(all('section.level1', visible: :all).size).to eq(song_count + 1) # +1 for Introduction

    expect(page).to have_css('.slide-content', visible: :all)

    expect(page.evaluate_script("Reveal.getTotalSlides()")).to be > song_count
  end

  it 'strips Resources sections' do
    expect(all('section[id^="resources"]', visible: :all)).to be_empty
    expect(all('h2', visible: :all).map { |el| el.text(:all) }).not_to include('Resources')
  end

  it 'uses the serif (light) theme' do
    hex = page.evaluate_script(
      "getComputedStyle(document.documentElement).getPropertyValue('--r-background-color').trim()"
    ).gsub(/[^0-9a-fA-F]/, '')
    r, g, b = hex[0..1].to_i(16), hex[2..3].to_i(16), hex[4..5].to_i(16)
    expect(r + g + b).to be > 400
  end
end
