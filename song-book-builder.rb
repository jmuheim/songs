#!/usr/bin/ruby

# require 'pry'

markdown = []
markdown << <<~EOS
              ---
              author: 😊 Monika and friends ❤️
              title:  Our Favourite Guitar Songs 🔥🎶🌛
              ---
            EOS

markdown << File.open("Introduction.md").read

markdown += Dir["songs/*.md"].sort.map do |filename|
              content = File.open(filename).read
            
              content.gsub!(/(\[)(([A-Z]).*?)(\])([^\(])/) do
                "`#{$2}`{.#{$3.downcase}}#{$5}"
              end
            end

file = File.new("tmp/all-songs.md", "w")
file.puts(markdown.join("\n"))
file.close

# HTML slides (Reveal.js)
puts `pandoc -t revealjs -s -o index.html tmp/all-songs.md --slide-level=2 --no-highlight --toc --toc-depth=1 -V theme=night -V progress=false -V revealjs-url=./revealjs`

result = File.open("index.html").read

result.gsub!("<body>", '<body><input type="checkbox" id="toggle-chords-visibility" /><label for="toggle-chords-visibility"></label><a href="#" id="toggle-theme" onclick="document.getElementById(\'theme\').setAttribute(\'href\',\'revealjs/css/theme/serif.css\'); return false;"></a><a href="#/1" id="go-to-toc"></a>')
result.gsub!('<style>', '<style>' + File.open("css/night.css").read + File.open("css/shared.css").read)

file = File.open("index.html", "w")
file.write(result)
file.close

# Word
# puts `pandoc -s -o songs.docx tmp/all-songs.md --no-highlight --toc --toc-depth=1`

# Powerpoint
# puts `pandoc -s -o songs.pptx tmp/all-songs.md --slide-level=2`

# Printable song book
puts `pandoc -t revealjs -s -o tmp/print.html tmp/all-songs.md --slide-level=2 --no-highlight --toc --toc-depth=1 -V theme=serif -V progress=false -V revealjs-url=../revealjs`

result = File.open("tmp/print.html").read

result.gsub!('<style>', '<style>' + File.open("css/serif.css").read + File.open("css/shared.css").read) # Add 
result.gsub!(/<section id="resources[-\d]*?" class="slide level2">(.*?)<\/section>/m, "") # Remove "Resources" slides (they contain links that are useless/ugly in a printed document)

file = File.open("tmp/print.html", "w")
file.write(result)
file.close

print_file = "#{URI::encode(File.expand_path(File.dirname(__FILE__))).to_s}/tmp/print.html"
`rm -rf tmp/screenshots/*`
puts `decktape -s 1600x1200 file://#{print_file} print.pdf`
