require 'capybara/rspec'

RSpec.describe 'print.html', :js, type: :feature do
  before(:all) do
    FileServer.start
    Capybara.app_host = FileServer.url
  end

  before do
    visit '/print.html'
    sleep 1.5
  end

  it 'loads and shows a title' do
    expect(page.title).not_to be_empty
  end

  it 'renders the title slide' do
    expect(page).to have_css('#title-slide', visible: :all)
    expect(first('#title-slide', visible: :all).text(:all)).to include('Lieblings-Songs')
  end

  it 'has no Resources sections in the DOM' do
    resource_sections = all('section[id^="resources"]', visible: :all)
    expect(resource_sections).to be_empty
  end

  it 'has no heading with text Resources' do
    h2_texts = all('h2', visible: :all).map { |el| el.text(:all) }
    expect(h2_texts).not_to include('Resources')
  end

  it 'renders chord code elements in the DOM' do
    chord_codes = all('section code', visible: :all).select { |el| el[:class]&.match?(/\A[a-g]\z/) }
    expect(chord_codes).not_to be_empty
  end

  it 'wraps slide content in .slide-content divs' do
    expect(page).to have_css('.slide-content', visible: :all)
  end

  it 'uses the serif (light) theme' do
    # Reveal.js stores theme background in --r-background-color CSS variable
    hex = page.evaluate_script(
      "getComputedStyle(document.documentElement).getPropertyValue('--r-background-color').trim()"
    ).gsub(/[^0-9a-fA-F]/, '')
    r, g, b = hex[0..1].to_i(16), hex[2..3].to_i(16), hex[4..5].to_i(16)
    expect(r + g + b).to be > 400
  end

  it 'sets the title slide background image attribute' do
    title = first('#title-slide', visible: :all)
    expect(title[:'data-background-image']).to include('background.jpg')
  end

  it 'has song slides for all active songs (plus introduction)' do
    song_count = Dir[File.join(PROJECT_ROOT, 'content', 'songs', '*.md')].size
    level1_sections = all('section.level1', visible: :all)
    expect(level1_sections.size).to eq(song_count + 1)
  end

  it 'Reveal.js is initialized and reports slides' do
    total = page.evaluate_script("Reveal.getTotalSlides()")
    expect(total).to be > 10
  end
end
