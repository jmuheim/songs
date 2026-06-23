require 'nokogiri'

module BuildHelpers
  module_function

  CHORD_REGEX = /\[([A-Z][^\]]*)\](?!\()/

  def validate_song!(path, content)
    name = File.basename(path)
    errors = []

    errors << "must be valid UTF-8"               unless content.valid_encoding?
    errors << "must not have Windows line endings" if content.include?("\r\n")

    h1s = content.lines.select { |l| l.start_with?('# ') }
    errors << "must have exactly one H1 (found #{h1s.size})" unless h1s.size == 1

    h2s = content.lines.select { |l| l.start_with?('## ') }
    errors << "must have at least one H2 section (found #{h2s.size})" if h2s.empty?

    opens, closes = content.count('['), content.count(']')
    errors << "has mismatched brackets (#{opens} [ vs #{closes} ])" unless opens == closes

    bad_chords = content.scan(/\[([^\]]+)\](?!\()/).flatten
      .select { |c| c.match?(/^[A-Z]/) && c.include?(' ') }
    errors << "has chord names with spaces: #{bad_chords.inspect}" unless bad_chords.empty?

    return if errors.empty?
    abort "#{name}: #{errors.join('; ')}"
  end

  def transform_chords(text)
    text.gsub(CHORD_REGEX) { "`#{$1}`{.#{$1[0].downcase}}" }
  end

  def wrap_slide_content(html)
    doc = Nokogiri::HTML(html)
    doc.css('section[id], section[class]').each do |section|
      children = section.children.to_a
      wrapper = Nokogiri::XML::Node.new('div', doc)
      wrapper['class'] = 'slide-content'
      section.add_child(wrapper)
      children.each { |child| wrapper.add_child(child) }
    end
    doc.to_html
  end
end
