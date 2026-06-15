require 'nokogiri'
require_relative '../../lib/build_helpers'

RSpec.describe 'wrap_slide_content' do
  include BuildHelpers

  def parse(html)
    Nokogiri::HTML(wrap_slide_content(html))
  end

  it 'wraps children of sections with id in a .slide-content div' do
    html = '<section id="intro"><h2>Hello</h2><p>World</p></section>'
    doc = parse(html)
    wrapper = doc.at_css('section#intro .slide-content')
    expect(wrapper).not_to be_nil
    expect(wrapper.at_css('h2').text).to eq('Hello')
    expect(wrapper.at_css('p').text).to eq('World')
  end

  it 'wraps children of sections with class' do
    html = '<section class="level1"><h1>Title</h1></section>'
    doc = parse(html)
    expect(doc.at_css('section.level1 .slide-content')).not_to be_nil
  end

  it 'wraps sections that have both id and class' do
    html = '<section id="my-song" class="slide level2"><h2>Song</h2><p>Lyrics</p></section>'
    doc = parse(html)
    wrapper = doc.at_css('section#my-song .slide-content')
    expect(wrapper).not_to be_nil
    expect(wrapper.children.map(&:name)).to include('h2', 'p')
  end

  it 'places the .slide-content div as a direct child of the section' do
    html = '<section id="s"><h2>Title</h2><p>text</p></section>'
    doc = parse(html)
    section = doc.at_css('section#s')
    direct_children = section.element_children.map { |c| c['class'] }
    expect(direct_children).to eq(['slide-content'])
  end

  it 'handles multiple sibling sections' do
    html = <<~HTML
      <section id="a"><p>A</p></section>
      <section id="b"><p>B</p></section>
    HTML
    doc = parse(html)
    expect(doc.at_css('section#a .slide-content p').text).to eq('A')
    expect(doc.at_css('section#b .slide-content p').text).to eq('B')
  end

  it 'handles nested sections (stack + level2)' do
    html = <<~HTML
      <section class="level1">
        <section id="verse" class="slide level2">
          <h2>Verse</h2>
        </section>
      </section>
    HTML
    doc = parse(html)
    expect(doc.at_css('section.level1 .slide-content')).not_to be_nil
    expect(doc.at_css('section#verse .slide-content h2').text).to eq('Verse')
  end

  it 'returns a valid HTML string' do
    result = wrap_slide_content('<section id="x"><p>hi</p></section>')
    expect(result).to be_a(String)
    expect(result).to include('<div class="slide-content">')
  end
end
