require 'capybara/rspec'

# The table of contents carries a tag-filter chip bar (built by inject_toc_filter
# in lib/build_helpers.rb, wired by style/toc-filter.js). The fixture songs are
# tagged so that Rock = {74-75} and Pop = {Across, I Have a Dream, Imagine} are
# disjoint — a clean test of single-tag filtering and OR across tags.
RSpec.describe 'TOC tag filter', :js, type: :feature do
  before(:all) do
    FixtureBuilder.build!
    FileServer.start
    MultiplexServer.start
    Capybara.app_host = FileServer.url
  end

  before do
    visit FixtureBuilder::URL_PATH
    wait_for_reveal
    click_link 'Table of contents' # the 📖 control → #/1
    expect(page).to have_css('#TOC.present')
  end

  # Titles of the TOC entries the filter leaves showing, whitespace-normalised.
  def visible_entries
    all('#TOC nav li:not(.toc-hidden) a', visible: :all).map { |a| a.text.gsub(/\s+/, ' ').strip }
  end

  it 'offers a chip per distinct tag plus „Alle", „Alle" active' do
    aggregate_failures do
      within '#toc-filter' do
        expect(page).to have_button('Alle')      # the reset chip
        expect(page).to have_button('Englisch')  # one chip per distinct tag, sorted
        expect(page).to have_button('Pop')
        expect(page).to have_button('Rock')
      end
      expect(page).to have_css('#toc-filter .toc-tag-all[aria-pressed="true"]')
      expect(visible_entries).to include('Introduction', '74-75 (The Connells)') # nothing hidden yet
    end
  end

  it 'filters to the clicked tag, toggles off on a second click, and never pages the deck' do
    click_button 'Rock'
    expect(visible_entries).to eq(['74-75 (The Connells)']) # Rock = {74-75}
    expect(page).to have_css('#toc-filter .toc-tag[data-tag="Rock"][aria-pressed="true"]')
    expect(page).to have_css('#toc-filter .toc-tag-all[aria-pressed="false"]')
    expect(page).to have_css('#TOC.present') # a chip click must not navigate the deck

    click_button 'Rock' # toggling the only tag off restores the full list
    expect(visible_entries).to include('Introduction', 'Imagine (John Lennon)')
    expect(page).to have_css('#toc-filter .toc-tag-all[aria-pressed="true"]')
  end

  it 'combines several selected tags with OR' do
    click_button 'Rock'
    click_button 'Pop'
    # Rock = {74-75}, Pop = the other three → the union is every song.
    expect(visible_entries).to contain_exactly(
      '74-75 (The Connells)',
      'Across the universe (Beatles)',
      'I Have a Dream (ABBA)',
      'Imagine (John Lennon)'
    )
  end

  it 'hides untagged entries while filtering and restores them with „Alle"' do
    click_button 'Pop'
    expect(visible_entries).not_to include('Introduction')          # untagged, so hidden
    expect(visible_entries).not_to include('74-75 (The Connells)')  # Rock only, no Pop
    expect(visible_entries.size).to eq(3)

    click_button 'Alle'
    expect(visible_entries).to include('Introduction', '74-75 (The Connells)')
    expect(page).to have_css('#toc-filter .toc-tag-all[aria-pressed="true"]')
    expect(page).to have_css('#toc-filter .toc-tag[data-tag="Pop"][aria-pressed="false"]')
  end
end
