require 'rspec/core/rake_task'
require 'fileutils'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :multiplex do
  desc 'Create the gitignored multiplex-token.json for local builds (offline, no network)'
  task :token do
    require 'json'
    require_relative 'lib/build_helpers'

    path = File.join(__dir__, 'multiplex-token.json')
    File.write(path, JSON.pretty_generate(BuildHelpers.generate_multiplex_token) + "\n")
    puts "🎲 Wrote #{path} (gitignored). Your local build now has its own multiplex session."
  end
end

namespace :golden do
  desc 'Regenerate golden HTML fixtures from the current fixture build'
  task :update do
    require 'nokogiri'
    require 'tmpdir'
    require_relative 'spec/support/fixture_builder'

    FixtureBuilder.build!
    doc = Nokogiri::HTML(File.read(FixtureBuilder::OUTPUT, encoding: 'UTF-8'))

    golden_dir = File.join(__dir__, 'spec', 'fixtures', 'golden')
    FileUtils.mkdir_p(golden_dir)

    imagine_title = doc.at_css('section#imagine-john-lennon')
    raise 'section#imagine-john-lennon not found' unless imagine_title

    across_title = doc.at_css('section#across-the-universe-beatles')
    raise 'section#across-the-universe-beatles not found' unless across_title

    sections = {
      'title_slide.html'   => doc.at_css('section.deck-title-slide'),
      'toc.html'           => doc.at_css('section#TOC'),
      'master_modal.html'  => doc.at_css('dialog#master-modal'),
      'imagine_verse1.html' => imagine_title
                                .xpath('following-sibling::section[.//h2[normalize-space()="Verse 1"]][1]')
                                .first,
      'infos_ueber_das_lied.html' => across_title
                                .xpath('following-sibling::section[.//h2[normalize-space()="Infos über das Lied"]][1]')
                                .first
    }

    sections.each do |filename, node|
      raise "Node for #{filename} not found in fixture HTML" unless node
      File.write(File.join(golden_dir, filename), node.to_html + "\n", encoding: 'UTF-8')
      puts "  updated spec/fixtures/golden/#{filename}"
    end
  end
end
