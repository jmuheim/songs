require 'capybara/rspec'

RSpec.describe 'theme toggle', :js, type: :feature do
  before(:all) do
    FileServer.start
    Capybara.app_host = FileServer.url
  end

  before do
    # Reset localStorage so a previous test's theme preference doesn't bleed in
    visit '/index.html'
    page.evaluate_script("localStorage.removeItem('theme')")
    visit '/index.html'
    sleep 1.5
  end

  def bg_brightness
    # Read from body: night.css overrides --r-background-color on body.theme-bright,
    # so body is the right scope (documentElement would return the :root value always).
    hex = page.evaluate_script(
      "getComputedStyle(document.body).getPropertyValue('--r-background-color').trim()"
    ).gsub(/[^0-9a-fA-F]/, '')
    # Expand 3-digit shorthand (#111 → #111111)
    hex = hex.chars.map { |c| c * 2 }.join if hex.length == 3
    r = hex[0..1]&.to_i(16) || 0
    g = hex[2..3]&.to_i(16) || 0
    b = hex[4..5]&.to_i(16) || 0
    r + g + b
  end

  it 'starts in dark (night) theme with no theme-bright class' do
    expect(page.evaluate_script("document.body.classList.contains('theme-bright')")).to be false
    expect(bg_brightness).to be < 150
  end

  it 'switches to bright theme after clicking #toggle-theme' do
    find('#toggle-theme').click
    sleep 0.2
    expect(page.evaluate_script("document.body.classList.contains('theme-bright')")).to be true
    expect(bg_brightness).to be > 500
  end

  it 'switches back to dark theme on a second click' do
    find('#toggle-theme').click
    sleep 0.2
    find('#toggle-theme').click
    sleep 0.2
    expect(page.evaluate_script("document.body.classList.contains('theme-bright')")).to be false
  end

  it 'persists the bright theme preference in localStorage' do
    find('#toggle-theme').click
    sleep 0.2
    stored = page.evaluate_script("localStorage.getItem('theme')")
    expect(stored).to eq('bright')
  end

  it 'persists the dark theme preference in localStorage after toggling back' do
    find('#toggle-theme').click
    sleep 0.2
    find('#toggle-theme').click
    sleep 0.2
    stored = page.evaluate_script("localStorage.getItem('theme')")
    expect(stored).to eq('dark')
  end

  it 'restores the bright theme on page reload when localStorage says bright' do
    find('#toggle-theme').click
    sleep 0.2
    visit '/index.html'
    sleep 1.0
    expect(page.evaluate_script("document.body.classList.contains('theme-bright')")).to be true
  end
end
