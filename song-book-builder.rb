#!/usr/bin/ruby

require 'optparse'

options = { pdf: false, deploy: false }

OptionParser.new do |opts|
  opts.banner = "Usage: song-book-builder.rb [options]"
  opts.on("--pdf", "Generate PDF (slow)") { options[:pdf] = true }
  opts.on("--deploy", "Deploy to josh.ch/songs via rsync") { options[:deploy] = true }
end.parse!

def step(emoji, label)
  print "#{emoji}  #{label}... "
  t = Time.now
  result = yield
  puts "✅ (#{"%.1f" % (Time.now - t)}s)"
  result
end

puts "🎸 Building song book"
puts

# Collect and transform songs
song_files = Dir["content/songs/*.md"].sort

puts "🎵 Songs (#{song_files.size}):"
song_files.each { |f| puts "   🎶 #{File.basename(f, ".md")}" }
puts

markdown = []
markdown << <<~EOS
              ---
              title:  Lieblings-Songs 🔥🎶🌛
              author: 😊 Josua & Monika ❤️
              ---
            EOS

markdown << File.open("content/Introduction.md").read

markdown += song_files.map do |filename|
  File.open(filename).read.gsub(/(\[)(([A-Z]).*?)(\])([^\(])/) do
    "`#{$2}`{.#{$3.downcase}}#{$5}"
  end
end

step("📝", "Writing all-songs.md") do
  file = File.new("all-songs.md", "w")
  file.puts(markdown.join("\n"))
  file.close
end

# HTML slides (Reveal.js)
step("🌙", "Generating index.html (Pandoc)") do
  output = `pandoc -t revealjs -s -o index.html all-songs.md --slide-level=2 --syntax-highlighting=none --toc --toc-depth=1 -V theme=night -V progress=false -V revealjs-url=./style/revealjs 2>&1`
  print output unless output.strip.empty?
end

step("✨", "Post-processing index.html") do
  result = File.open("index.html").read
  result.gsub!("<body>", '<body><input type="checkbox" id="toggle-chords-visibility" /><label for="toggle-chords-visibility"></label><a href="#" id="toggle-theme" onclick="document.getElementById(\'theme\').setAttribute(\'href\',\'revealjs/style/theme/serif.css\'); return false;"></a><a href="#/1" id="go-to-toc"></a>')
  result.gsub!('<style>', '<style>' + File.open("style/night.css").read + File.open("style/shared.css").read)
  File.open("index.html", "w") { |f| f.write(result) }
end

# Word
# `pandoc -s -o songs.docx all-songs.md --syntax-highlighting=none --toc --toc-depth=1`

# Powerpoint
# `pandoc -s -o songs.pptx all-songs.md --slide-level=2`

# Printable song book
step("🖨️", "Generating print.html (Pandoc)") do
  output = `pandoc -t revealjs -s -o print.html all-songs.md --slide-level=2 --syntax-highlighting=none --toc --toc-depth=1 -V theme=serif -V progress=false -V revealjs-url=./style/revealjs 2>&1`
  print output unless output.strip.empty?
end

step("✨", "Post-processing print.html") do
  result = File.open("print.html").read
  result.gsub!('<style>', '<style>' + File.open("style/serif.css").read + File.open("style/shared.css").read)
  result.gsub!(/<section id="resources[-\d]*?" class="slide level2">(.*?)<\/section>/m, "")
  result.gsub!('<section id="title-slide"', '<section id="title-slide" data-background-image="style/background.jpg"')
  File.open("print.html", "w") { |f| f.write(result) }
end

if options[:pdf]
  step("📄", "Generating print.pdf (DeckTape)") do
    print_file = "#{URI::encode(File.expand_path(File.dirname(__FILE__))).to_s}/print.html"
    output = `decktape -s 1600x1200 file://#{print_file} print.pdf 2>&1`
    print "\n#{output}" unless output.strip.empty?
  end
end

if options[:deploy]
  step("🚀", "Deploying to josh.ch/songs") do
    remote = "maroni@greip.uberspace.de:/var/www/virtual/maroni/josh.ch/songs/"
    output = `rsync -avz --delete index.html style #{remote} 2>&1`
    print "\n#{output}" unless output.strip.empty?
  end
end

puts
puts "🎉 Done!"
