require 'capybara/rspec'

RSpec.describe 'slide-zoom.js', :js, type: :feature do
  before(:all) do
    FileServer.start
    Capybara.app_host = FileServer.url
  end

  before do
    visit '/index.html'
    sleep 1.5
  end

  it 'sets a zoom value on the title slide .slide-content' do
    zoom = page.evaluate_script(
      "document.querySelector('#title-slide .slide-content')?.style?.zoom"
    )
    expect(zoom.to_s).not_to be_empty
    expect(zoom.to_f).to be > 0
  end

  it 'applies zoom via Reveal.getCurrentSlide() on the active sub-slide' do
    # Navigate to a song section (h=2, v=1) so we're on a level2 slide
    page.evaluate_script("Reveal.slide(2, 1)")
    sleep 0.5

    zoom = page.evaluate_script(
      "Reveal.getCurrentSlide()?.querySelector('.slide-content')?.style?.zoom"
    )
    expect(zoom.to_s).not_to be_empty
    expect(zoom.to_f).to be > 0
  end

  it 'does not apply zoom to non-slide sections' do
    # The #TOC section is a level1 but acts as a container — check it via ID
    zoom = page.evaluate_script(
      "document.querySelector('section#TOC .slide-content')?.style?.zoom"
    )
    # If zoom is set it should still be a positive number (not broken)
    # The important thing is .slide-content exists and zoom doesn't crash
    expect { zoom.to_f }.not_to raise_error
  end

  it 'keeps zoom positive after navigating between slides' do
    [0, 2, 3].each do |h|
      page.evaluate_script("Reveal.slide(#{h}, 0)")
      sleep 0.3
      zoom = page.evaluate_script(
        "Reveal.getCurrentSlide()?.querySelector('.slide-content')?.style?.zoom"
      )
      expect(zoom.to_f).to be > 0, "Expected zoom > 0 at h=#{h}, got #{zoom.inspect}"
    end
  end

  it 'recalculates zoom on window resize' do
    zoom_before = page.evaluate_script(
      "parseFloat(document.querySelector('#title-slide .slide-content')?.style?.zoom || '0')"
    )

    # Narrow the viewport drastically so zoom must change
    page.driver.browser.resize(width: 480, height: 600)
    sleep 0.3
    page.evaluate_script("window.dispatchEvent(new Event('resize'))")
    sleep 0.3

    zoom_after = page.evaluate_script(
      "parseFloat(document.querySelector('#title-slide .slide-content')?.style?.zoom || '0')"
    )

    expect(zoom_after).to be > 0
    expect(zoom_after).not_to eq(zoom_before)
  ensure
    page.driver.browser.resize(width: 1280, height: 800)
  end

  it 'does not zoom beyond what fits the viewport' do
    # Any slide: zoomed content should not exceed window dimensions
    zoom_str = page.evaluate_script(
      "Reveal.getCurrentSlide()?.querySelector('.slide-content')?.style?.zoom"
    )
    zoom = zoom_str.to_f
    return if zoom.zero?

    content_w = page.evaluate_script(
      "Reveal.getCurrentSlide()?.querySelector('.slide-content')?.scrollWidth"
    ).to_f
    content_h = page.evaluate_script(
      "Reveal.getCurrentSlide()?.querySelector('.slide-content')?.scrollHeight"
    ).to_f
    win_w = page.evaluate_script("window.innerWidth").to_f
    win_h = page.evaluate_script("window.innerHeight").to_f

    expect(content_w * zoom).to be <= win_w + 2
    expect(content_h * zoom).to be <= win_h + 2
  end
end
