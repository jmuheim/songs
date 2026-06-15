require 'capybara/rspec'

RSpec.describe 'index.html presentation', :js, type: :feature do
  before(:all) do
    FileServer.start
    Capybara.app_host = FileServer.url
  end

  before do
    visit '/index.html'
    sleep 1.5
  end

  it 'renders the title slide as the initial visible slide' do
    expect(page).to have_css('#title-slide.present')
  end

  it 'shows the song book title on the title slide' do
    expect(find('#title-slide')).to have_text('Lieblings-Songs')
  end

  it 'shows the authors on the title slide' do
    expect(find('#title-slide')).to have_text('Josua')
  end

  it 'has a TOC section in the DOM with links to all songs' do
    toc = first('#TOC', visible: :all)
    expect(toc).not_to be_nil
    links = toc.all('a', visible: :all)
    expect(links.size).to be >= 5
  end

  it 'lists ABBA in the TOC' do
    toc = first('#TOC', visible: :all)
    expect(toc.text(:all)).to include('ABBA')
  end

  it 'has chord code elements in the DOM with color CSS classes' do
    chord_codes = all('section code', visible: :all).select { |el| el[:class]&.match?(/\A[a-g]\z/) }
    expect(chord_codes).not_to be_empty
  end

  it 'has the master mode button (#master-mode)' do
    expect(page).to have_css('#master-mode')
  end

  it 'has the QR code button (#show-qr)' do
    expect(page).to have_css('#show-qr')
  end

  it 'has the chord visibility toggle button (#toggle-chords-visibility)' do
    expect(page).to have_css('#toggle-chords-visibility')
  end

  it 'wraps slide content in .slide-content divs' do
    expect(page).to have_css('.slide-content', visible: :all)
  end

  it 'uses the night theme (dark background)' do
    # Night theme sets --r-background-color on :root; check the Reveal.js container
    bg = page.evaluate_script(
      "getComputedStyle(document.querySelector('.reveal') || document.body).backgroundColor"
    )
    # bg is "rgb(R, G, B)" — sum should be very low for a dark theme
    numbers = bg.scan(/\d+/).map(&:to_i)
    expect(numbers.sum).to be < 150
  end

  it 'can navigate to the next horizontal slide via Reveal.js API' do
    initial_h = page.evaluate_script("Reveal.getIndices().h")
    page.evaluate_script("Reveal.right()")
    sleep 0.3
    new_h = page.evaluate_script("Reveal.getIndices().h")
    expect(new_h).to be > initial_h
  end

  it 'can navigate to a sub-slide (vertical) via Reveal.js API' do
    page.evaluate_script("Reveal.slide(2, 0)")
    sleep 0.3
    page.evaluate_script("Reveal.down()")
    sleep 0.3
    v = page.evaluate_script("Reveal.getIndices().v")
    expect(v).to be > 0
  end

  it 'Reveal.js is initialized and reports total slide count' do
    song_count = Dir[File.join(PROJECT_ROOT, 'content', 'songs', '*.md')].size
    total = page.evaluate_script("Reveal.getTotalSlides()")
    expect(total).to be > song_count
  end

  it 'has the multiplex config embedded as a window global' do
    socket_id = page.evaluate_script("window.MULTIPLEX && window.MULTIPLEX.socketId")
    expect(socket_id).not_to be_nil
    expect(socket_id).not_to be_empty
  end
end
