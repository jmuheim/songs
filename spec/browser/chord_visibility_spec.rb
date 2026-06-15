require 'capybara/rspec'

RSpec.describe 'chord visibility toggle', :js, type: :feature do
  before(:all) do
    FileServer.start
    Capybara.app_host = FileServer.url
  end

  before do
    visit '/index.html'
    sleep 1.5
    # Navigate to a song slide that has chords
    page.evaluate_script("Reveal.slide(2, 1)")
    sleep 0.4
  end

  def chord_display
    page.evaluate_script(
      "getComputedStyle(document.querySelector('section.present code') || document.querySelector('section code')).display"
    )
  end

  it 'shows chords initially (display is not none)' do
    expect(page.evaluate_script("document.body.classList.contains('chords-hidden')")).to be false
    expect(chord_display).not_to eq('none')
  end

  it 'hides chord code elements after one click on the toggle button' do
    find('#toggle-chords-visibility').click
    sleep 0.2
    expect(page.evaluate_script("document.body.classList.contains('chords-hidden')")).to be true
    expect(chord_display).to eq('none')
  end

  it 'shows chords again after a second click (toggle back)' do
    find('#toggle-chords-visibility').click
    sleep 0.2
    find('#toggle-chords-visibility').click
    sleep 0.2
    expect(page.evaluate_script("document.body.classList.contains('chords-hidden')")).to be false
    expect(chord_display).not_to eq('none')
  end

  it 'toggle button does not steal focus from the presentation (blurs itself)' do
    find('#toggle-chords-visibility').click
    sleep 0.2
    # After click the button should not be the focused element
    focused = page.evaluate_script("document.activeElement?.id || ''")
    expect(focused).not_to eq('toggle-chords-visibility')
  end
end
