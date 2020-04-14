#!/usr/bin/ruby

# require 'pry'

markdown = []
markdown << <<~EOS
              ---
              author: Joshua and friends
              title:  Our Songs
              ---
            EOS

Dir["songs/*.md"].sort.each do |filename|
  content = File.open(filename).read

  content.gsub!(/(\[)(([A-Z]).*?)(\])([^\(])/) do
    "`#{$2}`{.#{$3.downcase}}#{$5}"
  end

  markdown << content
end

file = File.new("all-songs.md", "w")
file.puts(markdown.join("\n"))
file.close

`pandoc -t revealjs -s -o index.html all-songs.md --no-highlight --toc --toc-depth=1 -V theme=night -V progress=false -V revealjs-url=https://revealjs.com`

result = File.open("index.html").read
result.gsub!("<body>", '<body><input type="checkbox" id="toggle-chords-visibility" /><label for="toggle-chords-visibility"></label>')

result.gsub!('<style type="text/css">', '<style type="text/css">' + File.open("custom.css").read)

file = File.open("index.html", "w")
file.write(result)
file.close

`unlink all-songs.md`
