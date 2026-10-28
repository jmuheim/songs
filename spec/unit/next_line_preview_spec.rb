require 'nokogiri'
require_relative '../../lib/build_helpers'

RSpec.describe 'inject_next_line_previews' do
  include BuildHelpers

  # The shape Pandoc gives a song: a stack <section> holding its title slide
  # (level1) and its sub-slides (level2), inside div.slides. The first stack is
  # always the Introduction (songbook_markdown prepends it).
  def deck(*stacks)
    %(<div class="reveal"><div class="slides">#{stacks.join}</div></div>)
  end

  INTRODUCTION = <<~HTML.freeze
    <section>
    <section id="introduction" class="title-slide slide level1"><h1>Introduction</h1></section>
    <section id="welcome" class="slide level2"><h2>Welcome</h2><p>Hello</p></section>
    <section id="basic-chords" class="slide level2"><h2>Basic chords</h2><pre><code>x Not played</code></pre></section>
    </section>
  HTML

  SONG = <<~HTML.freeze
    <section>
    <section id="riptide" class="title-slide slide level1"><h1>Riptide - Vance Joy</h1></section>
    <section id="infos-über-das-lied" class="slide level2"><h2>Infos über das Lied</h2><ul><li>Sprache: Englisch</li></ul></section>
    <section id="intro" class="slide level2"><h2>Intro</h2><p><code class="a">Am</code> <code class="g">G</code> <em>(x2)</em></p></section>
    <section id="verse-1" class="slide level2"><h2>Verse 1</h2><p>I was <code class="a">Am</code> scared of
    <code class="g">G</code> dentists <em>(slowly)</em><br>
    and the <code class="c">C</code> dark</p></section>
    <section id="chorus-2x" class="slide level2"><h2>Chorus <em>(2x)</em></h2><p>Lady, running down to the riptide</p></section>
    </section>
  HTML

  let(:doc) { Nokogiri::HTML(inject_next_line_previews(deck(INTRODUCTION, SONG))) }

  def preview(id)
    doc.css("section##{id} > p.next-line")
  end

  it "ends each sub-slide on the next one's heading and its first line, up to the first <br>" do
    expect(preview('intro').size).to eq(1)
    expect(preview('intro').first.inner_html)
      .to eq('Next: <span class="next-line-section">Verse 1</span> - I was <code class="a">Am</code> scared of <code class="g">G</code> dentists <em>(slowly)</em>...')
  end

  it 'keeps the chords (as <code>, for their colours) and the emphasis of that line' do
    line = preview('intro').first
    expect(line.css('code').map { |c| [c['class'], c.text] }).to eq([%w[a Am], %w[g G]])
    expect(line.at_css('em').text).to eq('(slowly)')
  end

  it "uses the next heading's text, without its markup" do
    expect(preview('verse-1').first.at_css('.next-line-section').text).to eq('Chorus (2x)')
  end

  it 'joins the lines Pandoc soft-wrapped back into one, as they read' do
    expect(preview('intro').first.text).to eq('Next: Verse 1 - I was Am scared of G dentists (slowly)...')
  end

  it "tells the song's last sub-slide that the song ends there" do
    last = preview('chorus-2x').first
    expect(last['class']).to eq('next-line next-line-end')
    expect(last.text).to eq(BuildHelpers::NEXT_LINE_END)
  end

  it 'leaves every preview to screen readers too: a follower in a live-scroll session cannot move on to read ahead' do
    expect(doc.css('p.next-line[aria-hidden]')).to be_empty
  end

  it "leaves the song's own title slide and its Infos slide alone: nothing is sung there yet" do
    expect(preview('riptide')).to be_empty
    expect(doc.css('section[id="infos-über-das-lied"] p.next-line')).to be_empty
  end

  it 'leaves the Introduction alone, which is no song' do
    expect(doc.css('section#welcome p.next-line, section#basic-chords p.next-line')).to be_empty
  end

  it 'takes the first line of a code block, should a slide open on one' do
    song = SONG.sub('<p>Lady, running down to the riptide</p>',
                    "<pre><code>e|--0--|\nB|--1--|</code></pre>")
    doc = Nokogiri::HTML(inject_next_line_previews(deck(INTRODUCTION, song)))
    expect(doc.at_css('section#verse-1 > p.next-line').text).to eq('Next: Chorus (2x) - e|--0--|...')
  end

  it 'puts the preview last, so wrap_slide_content carries it into .slide-content below the lyrics' do
    wrapped = Nokogiri::HTML(wrap_slide_content(inject_next_line_previews(deck(INTRODUCTION, SONG))))
    expect(wrapped.at_css('section#intro > .slide-content').element_children.map { |e| e['class'] || e.name })
      .to eq(%w[h2 p next-line])
  end
end
