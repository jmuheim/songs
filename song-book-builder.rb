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

out_file = File.new("songs.md", "w")
out_file.puts(markdown.join("\n"))
out_file.close

`pandoc -t revealjs -s -o index.html songs.md --no-highlight --toc --toc-depth=1 -V theme=night -V progress=false -V revealjs-url=./reveal.js`
