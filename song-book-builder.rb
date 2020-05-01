#!/usr/bin/ruby

# require 'pry'

markdown = []
markdown << <<~EOS
              ---
              author: 😊 Joshua and friends ❤️
              title:  Our Songs 🔥🎶🌛
              ---
            EOS

markdown << File.open("Chords.md").read

markdown += Dir["songs/*.md"].sort.map do |filename|
              content = File.open(filename).read
            
              content.gsub!(/(\[)(([A-Z]).*?)(\])([^\(])/) do
                "`#{$2}`{.#{$3.downcase}}#{$5}"
              end
            end

file = File.new("all-songs.md", "w")
file.puts(markdown.join("\n"))
file.close

`pandoc -s -o index.docx all-songs.md --no-highlight --toc --toc-depth=1 -V theme=night -V progress=false -V revealjs-url=./revealjs`

result = File.open("index.html").read
result.gsub!("<body>", '<body><input type="checkbox" id="toggle-chords-visibility" /><label for="toggle-chords-visibility"></label><a href="#" id="toggle-theme" onclick="document.getElementById(\'theme\').setAttribute(\'href\',\'revealjs/css/theme/serif.css\'); return false;"></a><a href="#/1" id="go-to-toc"></a>')

result.gsub!('<style type="text/css">', '<style type="text/css">' + File.open("custom.css").read)

file = File.open("index.html", "w")
file.write(result)
file.close

`unlink all-songs.md`
