#!/usr/bin/ruby

# require 'pry'

markdown = []
markdown << <<~EOS
              ---
              author: 😊 Joshua and friends ❤️
              title:  Our Songs 🔥🎶🌛
              ---
            EOS

markdown << File.open("content/Introduction.md").read

markdown += Dir["content/songs/*.md"].sort.map do |filename|
              content = File.open(filename).read

              content.gsub!(/(\[)(([A-Z]).*?)(\])([^\(])/) do
                "`#{$2}`{.#{$3.downcase}}#{$5}"
              end
            end

file = File.new("all-songs.md", "w")
file.puts(markdown.join("\n"))
file.close

# HTML slides (Reveal.js)
puts `pandoc -t revealjs -s -o index.html all-songs.md --slide-level=2 --no-highlight --toc --toc-depth=1 -V theme=night -V progress=false -V revealjs-url=./style/revealjs`

result = File.open("index.html").read

result.gsub!("<body>", '<body><input type="checkbox" id="toggle-chords-visibility" /><label for="toggle-chords-visibility"></label><a href="#" id="toggle-theme" onclick="document.getElementById(\'theme\').setAttribute(\'href\',\'revealjs/style/theme/serif.css\'); return false;"></a><a href="#/1" id="go-to-toc"></a>')
result.gsub!('<style>', '<style>' + File.open("style/night.css").read + File.open("style/shared.css").read)

file = File.open("index.html", "w")
file.write(result)
file.close

# Word
# puts `pandoc -s -o songs.docx all-songs.md --no-highlight --toc --toc-depth=1`

# Powerpoint
# puts `pandoc -s -o songs.pptx all-songs.md --slide-level=2`

# Printable song book
puts `pandoc -t revealjs -s -o print.html all-songs.md --slide-level=2 --no-highlight --toc --toc-depth=1 -V theme=serif -V progress=false -V revealjs-url=./style/revealjs`

result = File.open("print.html").read

result.gsub!('<style>', '<style>' + File.open("style/serif.css").read + File.open("style/shared.css").read) # Add 
result.gsub!(/<section id="resources[-\d]*?" class="slide level2">(.*?)<\/section>/m, "") # Remove "Resources" slides (they contain links that are useless/ugly in a printed document)
result.gsub!('<section id="title-slide"', '<section id="title-slide" data-background-image="style/background.jpg"') # Add background to title slide

file = File.open("print.html", "w")
file.write(result)
file.close

print_file = "#{URI::encode(File.expand_path(File.dirname(__FILE__))).to_s}/print.html"
puts `decktape -s 1600x1200 file://#{print_file} print.pdf`
