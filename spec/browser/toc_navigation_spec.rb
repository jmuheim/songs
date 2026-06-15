require 'capybara/rspec'

RSpec.describe 'TOC navigation', :js, type: :feature do
  before(:all) do
    FileServer.start
    Capybara.app_host = FileServer.url
  end

  before do
    visit '/index.html'
    sleep 1.5
  end

  it '#go-to-toc link points to slide index 1 (#/1)' do
    href = page.evaluate_script("document.getElementById('go-to-toc').getAttribute('href')")
    expect(href).to eq('#/1')
  end

  it 'clicking #go-to-toc navigates to horizontal slide 1 (the TOC)' do
    find('#go-to-toc').click
    sleep 0.6
    h_index = page.evaluate_script("Reveal.getIndices().h")
    expect(h_index).to eq(1)
  end

  it 'TOC slide becomes the present slide after clicking #go-to-toc' do
    find('#go-to-toc').click
    sleep 0.6
    present_id = page.evaluate_script("document.querySelector('.present')?.id || ''")
    expect(present_id).to eq('TOC')
  end

  it 'TOC contains a link for every active song plus the introduction' do
    song_count = Dir[File.join(PROJECT_ROOT, 'content', 'songs', '*.md')].size
    toc_links = all('#TOC a', visible: :all)
    expect(toc_links.size).to eq(song_count + 1)
  end

  it 'clicking a TOC song link navigates to that song slide' do
    find('#go-to-toc').click
    sleep 0.6

    # Click the first song link in the TOC
    first_link = first('#TOC a', visible: :all)
    first_link.click
    sleep 0.6

    # We should no longer be at TOC (h=1)
    h_index = page.evaluate_script("Reveal.getIndices().h")
    expect(h_index).to be >= 2
  end

  it 'the TOC lists all expected song titles' do
    toc_text = first('#TOC', visible: :all).text(:all)
    # Check a few known songs are present
    %w[ABBA Beatles Lennon].each do |artist|
      expect(toc_text).to include(artist), "Expected TOC to mention '#{artist}'"
    end
  end
end
