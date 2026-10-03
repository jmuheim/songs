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

  it 'tags each TOC entry with the tags from its About section' do
    imagine  = doc.at_css('#TOC a[href="#/imagine-john-lennon"]').parent
    connells = doc.at_css('#TOC a[href="#/the-connells"]').parent
    expect(imagine['data-tags']).to  eq('Englisch,Pop')
    expect(connells['data-tags']).to eq('Englisch,Rock')
    # The Introduction has no song behind it, so no tags.
    expect(doc.at_css('#TOC a[href="#/introduction"]').parent['data-tags']).to be_nil
  end

  it 'builds a chip per distinct tag, sorted, with „Alle" first and pressed' do
    chips = doc.css('#toc-filter .toc-tag').map { |b| b.text.strip }
    expect(chips).to eq(['Alle', 'Englisch', 'Pop', 'Rock'])
    expect(doc.at_css('#toc-filter .toc-tag-all')['aria-pressed']).to eq('true')
    expect(doc.at_css('#toc-filter .toc-tag[data-tag="Pop"]')['aria-pressed']).to eq('false')
  end

  it 'strips the About sections from print.html (tags are a screen feature)' do
    expect(print_doc.css('section[id^="about"]')).to be_empty
    expect(print_doc.at_css('#toc-filter')).to be_nil
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
