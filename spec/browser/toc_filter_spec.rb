require 'capybara/rspec'

# The table of contents carries a Sprache/Genre filter (built by inject_toc_filter
# in lib/build_helpers.rb, wired by style/toc-filter.js). The fixture songs are
# tagged so that Deutsch = {74-75} and Englisch = {Across, I Have a Dream, Imagine}
# are disjoint, and likewise Rock = {74-75} and Pop = the other three — a clean
# test of single-select filtering within a category and AND across categories.
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

  it 'offers a Sprache and a Genre dropdown, both unset, under a "Filter" legend' do
    aggregate_failures do
      within '#toc-filter' do
        expect(page).to have_css('legend', text: 'Filter')
        expect(page).to have_select('Sprache', options: ['Alle', 'Deutsch', 'Englisch'])
        expect(page).to have_select('Genre', options: ['Alle', 'Pop', 'Rock'])
        expect(page).to have_select('Sprache', selected: 'Alle')
        expect(page).to have_select('Genre', selected: 'Alle')
        expect(page).to have_button('Reset')
      end
      expect(visible_entries).to include('Introduction', '74-75 (The Connells)') # nothing hidden yet
    end
  end

  it 'filters to the selected Sprache, and restores everything on "Alle", without paging the deck' do
    select 'Deutsch', from: 'Sprache'
    expect(visible_entries).to eq(['74-75 (The Connells)']) # Deutsch = {74-75}
    expect(page).to have_css('#TOC.present') # a select change must not navigate the deck

    select 'Alle', from: 'Sprache'
    expect(visible_entries).to include('Introduction', 'Imagine (John Lennon)')
  end

  it 'combines Sprache and Genre with AND' do
    select 'Englisch', from: 'Sprache'
    select 'Pop', from: 'Genre'
    # Englisch ∩ Pop = the three Pop songs; 74-75 is Deutsch/Rock, so it drops out.
    expect(visible_entries).to contain_exactly(
      'Across the universe (Beatles)',
      'I Have a Dream (ABBA)',
      'Imagine (John Lennon)'
    )

    select 'Rock', from: 'Genre'
    # Englisch ∩ Rock is empty — 74-75 (the only Rock song) is Deutsch, not Englisch.
    expect(visible_entries).to be_empty
  end

  it 'hides untagged entries while filtering and restores them with Reset' do
    select 'Pop', from: 'Genre'
    expect(visible_entries).not_to include('Introduction')          # untagged, so hidden
    expect(visible_entries).not_to include('74-75 (The Connells)')  # Rock only, no Pop
    expect(visible_entries.size).to eq(3)

    click_button 'Reset'
    expect(visible_entries).to include('Introduction', '74-75 (The Connells)')
    expect(page).to have_select('Sprache', selected: 'Alle')
    expect(page).to have_select('Genre', selected: 'Alle')
  end

  it 'stays visible (sticky) while the list scrolls underneath it' do
    # The fixture book is too short to actually overflow #TOC (only 5 entries),
    # so this pins the CSS rather than scrolling a real overflow — the browser
    # specs for the live site, with 70+ songs, are where a scroll would show it.
    expect(page.evaluate_script("getComputedStyle(document.getElementById('toc-filter')).position")).to eq('sticky')
    expect(page.evaluate_script("getComputedStyle(document.getElementById('toc-filter')).top")).to eq('0px')
  end
end
