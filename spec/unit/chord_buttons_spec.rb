require 'nokogiri'
require_relative '../../lib/build_helpers'

RSpec.describe 'chord_buttons' do
  include BuildHelpers

  def parse(html)
    Nokogiri::HTML(chord_buttons(%(<div class="reveal"><div class="slides">#{html}</div></div>)))
  end

  it "wraps each chord's <code> in a real <button>, which keeps the code (its coloured pill) inside" do
    doc = parse('<section class="slide level2"><p>I was <code class="a">Am</code> scared of <code class="g">G7</code> dentists</p></section>')
    buttons = doc.css('section p > button')
    expect(buttons.map(&:to_html)).to eq([
      '<button type="button" class="chord"><code class="a">Am</code></button>',
      '<button type="button" class="chord"><code class="g">G7</code></button>'
    ])
    expect(doc.at_css('section p').text).to eq('I was Am scared of G7 dentists') # in place, nothing lost
  end

  it 'makes the percussive [X] a button too' do
    expect(parse('<section><p><code class="x">X</code></p></section>').at_css('button.chord code.x')).not_to be_nil
  end

  it "leaves code that isn't a chord alone: a fingering legend's <pre><code>, and a class chords.js has no fingering for" do
    doc = parse('<section><pre><code>A |x 0 2 2 2 0|</code></pre><p><code class="n">N.C.</code></p></section>')
    expect(doc.at_css('button')).to be_nil
  end
end
