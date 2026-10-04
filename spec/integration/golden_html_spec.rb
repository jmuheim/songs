require 'nokogiri'
require_relative '../../spec/support/fixture_builder'

GOLDEN_DIR = File.join(__dir__, '..', 'fixtures', 'golden')

RSpec.describe 'HTML golden files' do
  before(:all) { FixtureBuilder.build! }

  let(:doc)       { Nokogiri::HTML(File.read(FixtureBuilder::OUTPUT,       encoding: 'UTF-8')) }
  let(:print_doc) { Nokogiri::HTML(File.read(FixtureBuilder::PRINT_OUTPUT, encoding: 'UTF-8'), nil, 'UTF-8') }

  def golden(name)
    path = File.join(GOLDEN_DIR, name)
    raise "Golden file missing: #{path}\nRun `rake golden:update` to generate it." unless File.exist?(path)
    File.read(path, encoding: 'UTF-8')
  end

  it 'title slide HTML matches golden' do
    section = doc.at_css('section#title-slide')
    expect(section.to_html + "\n").to eq(golden('title_slide.html'))
  end

  it 'TOC HTML matches golden' do
    section = doc.at_css('section#TOC')
    expect(section.to_html + "\n").to eq(golden('toc.html'))
  end

  it 'tags each TOC entry with its Sprache/Genre from its Infos-über-das-Lied section' do
    imagine  = doc.at_css('#TOC a[href="#/imagine-john-lennon"]').parent
    connells = doc.at_css('#TOC a[href="#/the-connells"]').parent
    expect(imagine['data-sprache']).to  eq('Englisch')
    expect(imagine['data-genre']).to    eq('Pop')
    expect(connells['data-sprache']).to eq('Deutsch')
    expect(connells['data-genre']).to   eq('Rock')
  end

  it 'drops the Introduction from the TOC entirely — it has no song/tags behind it' do
    expect(doc.at_css('#TOC a[href="#/introduction"]')).to be_nil
  end

  it 'renders the TOC entries as an <ol>, not a <ul>' do
    expect(doc.at_css('#TOC nav ol')).not_to be_nil
    expect(doc.at_css('#TOC nav ul')).to be_nil
  end

  it 'builds a Sprache and a Genre dropdown, each sorted with „Alle" first, plus a Reset button' do
    sprache_options = doc.css('#toc-filter-sprache option').map { |o| o.text.strip }
    genre_options   = doc.css('#toc-filter-genre option').map { |o| o.text.strip }
    expect(sprache_options).to eq(['Alle', 'Deutsch', 'Englisch'])
    expect(genre_options).to   eq(['Alle', 'Pop', 'Rock'])
    legend = doc.at_css('#toc-filter legend')
    expect(legend.text.strip).to eq('Filter')
    expect(legend['class']).to eq('visually-hidden')
    expect(doc.at_css('#toc-filter-reset').text.strip).to eq('Reset')
  end

  it 'renders a hidden "no results" message after the TOC list, for the filter to reveal' do
    message = doc.at_css('#toc-filter-empty')
    expect(message.text.strip).to eq('Keine Ergebnisse, bitte Filter anpassen')
    expect(message['class']).to eq('toc-hidden')
  end

  it 'strips the Infos-über-das-Lied sections from print.html (tags, resources and fingerings are a screen feature)' do
    expect(print_doc.css('section[id^="infos-über-das-lied"]')).to be_empty
    expect(print_doc.at_css('#toc-filter')).to be_nil
  end

  it 'Infos über das Lied (merged with Instructions) HTML matches golden' do
    across_title = doc.at_css('section#across-the-universe-beatles')
    section = across_title
                .xpath('following-sibling::section[.//h2[normalize-space()="Infos über das Lied"]][1]')
                .first
    expect(section.to_html + "\n").to eq(golden('infos_ueber_das_lied.html'))
  end

  it 'master modal HTML matches golden' do
    dialog = doc.at_css('dialog#master-modal')
    expect(dialog.to_html + "\n").to eq(golden('master_modal.html'))
  end

  it 'Imagine Verse 1 HTML matches golden' do
    imagine_title = doc.at_css('section#imagine-john-lennon')
    section = imagine_title
                .xpath('following-sibling::section[.//h2[normalize-space()="Verse 1"]][1]')
                .first
    expect(section.to_html + "\n").to eq(golden('imagine_verse1.html'))
  end

  it 'Imagine Verse 1 in print.html matches golden (verifies chord rendering survives print pipeline)' do
    imagine_title = print_doc.at_css('section#imagine-john-lennon')
    section = imagine_title
                .xpath('following-sibling::section[.//h2[normalize-space()="Verse 1"]][1]')
                .first
    expect(section.to_html + "\n").to eq(golden('imagine_verse1_print.html'))
  end
end
