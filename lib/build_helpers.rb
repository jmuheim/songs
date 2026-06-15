require 'nokogiri'

module BuildHelpers
  module_function

  CHORD_REGEX = /\[([A-Z][^\]]*)\]([^\(])/

  def transform_chords(text)
    text.gsub(CHORD_REGEX) { "`#{$1}`{.#{$1[0].downcase}}#{$2}" }
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
