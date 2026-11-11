require 'rspec/core/rake_task'
require 'fileutils'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :golden do
  desc 'Regenerate golden HTML fixtures from the current fixture build'
  task :update do
    require 'nokogiri'
    require 'tmpdir'
    require_relative 'spec/support/fixture_builder'

    FixtureBuilder.build!
    doc = Nokogiri::HTML(File.read(FixtureBuilder::OUTPUT, encoding: 'UTF-8'))
    # Parsed as golden_html_spec.rb parses it, or the snapshot would differ
    print_doc = Nokogiri::HTML(File.read(FixtureBuilder::PRINT_OUTPUT, encoding: 'UTF-8'), nil, 'UTF-8')

    golden_dir = File.join(__dir__, 'spec', 'fixtures', 'golden')
    FileUtils.mkdir_p(golden_dir)

    imagine_title = doc.at_css('section#imagine-john-lennon')
    raise 'section#imagine-john-lennon not found' unless imagine_title

    print_imagine_title = print_doc.at_css('section#imagine-john-lennon')
    raise 'section#imagine-john-lennon not found in print.html' unless print_imagine_title

    across_title = doc.at_css('section#across-the-universe-beatles')
    raise 'section#across-the-universe-beatles not found' unless across_title

    sections = {
      'title_slide.html'   => doc.at_css('section.deck-title-slide'),
      'toc.html'           => doc.at_css('section#TOC'),
      'host_modal.html'    => doc.at_css('dialog#host-modal'),
      'imagine_title.html' => imagine_title,
      'imagine_verse1.html' => imagine_title
                                .xpath('following-sibling::section[.//h2[normalize-space()="Strophe 1"]][1]')
                                .first,
      'imagine_verse1_print.html' => print_imagine_title
                                .xpath('following-sibling::section[.//h2[normalize-space()="Strophe 1"]][1]')
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

namespace :fonts do
  # The settings dialog shows each font it offers as a picture of its name set
  # in it, so opening the dialog downloads a dozen small pictures instead of a
  # dozen fonts. This renders those pictures from the radio buttons in
  # body-controls.html (the img's src and alt) with the same @font-face rules
  # and night.css variables the song book uses: white on transparent, which
  # night.css darkens for the bright theme.
  desc 'Render the font samples of the settings dialog (style/fonts/samples/)'
  task :samples do
    require 'ferrum'
    require 'fileutils'
    require 'nokogiri'
    require_relative 'spec/support/file_server'

    FileServer.start
    browser = Ferrum::Browser.new(headless: true, browser_options: { 'no-sandbox': nil })
    # Fonts load only from the page's own origin, not from a file:// page
    browser.go_to(FileServer.url('/'))
    controls = Nokogiri::HTML.fragment(File.read(File.join(__dir__, 'style', 'body-controls.html'), encoding: 'UTF-8'))
    begin
      controls.css('.settings-fonts input[type="radio"]').each do |radio|
        img = radio.next_element
        title = radio['name'] == 'title-font'
        attribute = radio['value'].empty? ? '' : %( data-#{radio['name']}="#{radio['value']}")
        tag = title ? 'h1' : 'p'
        browser.content = <<~HTML
          <!doctype html>
          <html><head>
            <link rel="stylesheet" href="/style/fonts/fonts.css">
            <link rel="stylesheet" href="/style/revealjs/dist/theme/night.css">
            <link rel="stylesheet" href="/style/night.css">
            <style>
              html, body { margin: 0; background: transparent !important; }
              #sample { display: inline-block; margin: 0; padding: 0.1em 0.2em; font-size: 64px; line-height: 1.3; white-space: nowrap; color: #fff; text-shadow: none; }
            </style>
          </head><body#{attribute}><div class="reveal"><#{tag} id="sample">#{img['alt']}</#{tag}></div></body></html>
        HTML
        family = browser.evaluate("getComputedStyle(document.getElementById('sample')).fontFamily")[/\A"?([^",]+)/, 1]
        loaded = browser.evaluate_async(<<~JS, 10)
          var done = arguments[0];
          document.fonts.ready.then(function () {
            done(Array.from(document.fonts).some(function (f) { return f.family.replace(/"/g, '') === #{family.to_json} && f.status === 'loaded'; }));
          });
        JS
        raise "#{img['alt']}: #{family} did not load" unless loaded

        path = File.join(__dir__, img['src'].sub('{{assets}}', 'style/'))
        FileUtils.mkdir_p(File.dirname(path))
        browser.screenshot(path: path, selector: '#sample', background_color: Ferrum::RGBA.new(0, 0, 0, 0.0))
        puts "  rendered #{path.delete_prefix("#{__dir__}/")} (#{family})"
      end
    ensure
      browser.quit
    end
  end
end
