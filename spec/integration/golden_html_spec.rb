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

  it 'master modal HTML matches golden' do
    div = doc.at_css('div#master-modal')
    expect(div.to_html + "\n").to eq(golden('master_modal.html'))
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
