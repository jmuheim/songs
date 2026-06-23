require 'capybara/rspec'

RSpec.describe 'print.html', :js, type: :feature do
  before(:all) do
    FileServer.start
    Capybara.app_host = FileServer.url
  end

  def load_presentation
    visit '/print.html'
    wait_for_reveal
  end

  before { load_presentation }

  it 'has correct DOM structure and content' do
    expect(page.title).to eq('Lieblings-Songs 🔥🎶🌛')

    expect(page).to have_css('#title-slide', visible: :all)
    expect(first('#title-slide', visible: :all).text(:all)).to include('Lieblings-Songs')
    expect(first('#title-slide', visible: :all)[:'data-background-image']).to include('background.jpg')

    song_count = Dir[File.join(PROJECT_ROOT, 'content', 'songs', '*.md')].size
    expect(all('section.level1', visible: :all).size).to eq(song_count + 1)

    expect(all('section code.a, section code.b, section code.c, section code.d, section code.e, section code.f, section code.g', visible: :all)).not_to be_empty
    expect(page).to have_css('.slide-content', visible: :all)

    expect(page.evaluate_script("Reveal.getTotalSlides()")).to be > 10
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
