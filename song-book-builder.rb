#!/usr/bin/ruby

# require 'pry'

markdown = []
markdown << <<~EOS
              ---
              author: Joshua
              title:  My Guitar Songs
              date:   2020
              ---
            EOS

Dir["songs/*.md"].sort.each do |filename|
  content = File.open(filename).read

  content.gsub!(/(\[)(([A-Z])[a-z0-7]*?)(\])/) do
    "`#{$2}`{.#{$3.downcase}}"
  end

  markdown << content
end

File.new("songs.md", "w").puts(markdown.join("\n"))

`pandoc -t revealjs -s -o index.html songs.md --no-highlight --toc --toc-depth=1 -V theme=night -V progress=false -V revealjs-url=https://revealjs.com`

result = File.open("index.html").read
result.gsub!("<body>", '<body><input type="checkbox" id="toggle-chords-visibility" /><label for="toggle-chords-visibility"></label>')

result.gsub!('<style type="text/css">', '<style type="text/css">' + File.open("custom.css").read)

File.open("index.html", "w").write(result)
