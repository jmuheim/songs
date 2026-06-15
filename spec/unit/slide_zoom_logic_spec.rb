# Mirrors the logic in style/slide-zoom.js as Ruby for fast, dependency-free testing.
#
# isSlide predicate: section must be #title-slide, .level1, or .level2
# fitZoom formula:   Math.min(availW / contentW, availH / contentH)
#   – resets zoom to 1 first (so scrollWidth reflects natural size)
#   – skips if either dimension is 0

RSpec.describe 'slide-zoom.js logic' do
  # --- isSlide predicate ---

  def slide?(id, classes)
    id == 'title-slide' ||
      classes.include?('level1') ||
      classes.include?('level2')
  end

  describe 'isSlide predicate' do
    it 'recognises the title slide by id' do
      expect(slide?('title-slide', %w[title slide level1])).to be true
    end

    it 'recognises a level1 section by class' do
      expect(slide?('some-id', %w[level1])).to be true
      expect(slide?('',        %w[level1])).to be true
    end

    it 'recognises a level2 section by class' do
      expect(slide?('intro', %w[slide level2])).to be true
    end

    it 'rejects sections with none of the required markers' do
      expect(slide?('',          %w[slide])).to    be false
      expect(slide?('resources', %w[level3])).to   be false
      expect(slide?('',          [])).to            be false
    end

    it 'is not fooled by partial class name matches' do
      expect(slide?('', %w[slide sublevel2])).to   be false
      expect(slide?('', %w[not-level1-at-all])).to be false
    end
  end

  # --- fitZoom formula ---

  def fit_zoom(content_w, content_h, avail_w, avail_h)
    return nil unless content_w.positive? && content_h.positive?
    [avail_w.to_f / content_w, avail_h.to_f / content_h].min
  end

  describe 'fit_zoom formula' do
    it 'scales to width when width is the tighter constraint' do
      # content 400×100 in window 200×300: w-ratio=0.5, h-ratio=3 → 0.5
      expect(fit_zoom(400, 100, 200, 300)).to eq(0.5)
    end

    it 'scales to height when height is the tighter constraint' do
      # content 100×400 in window 400×200: w-ratio=4, h-ratio=0.5 → 0.5
      expect(fit_zoom(100, 400, 400, 200)).to eq(0.5)
    end

    it 'returns exactly 1.0 when content perfectly matches the viewport' do
      expect(fit_zoom(800, 600, 800, 600)).to eq(1.0)
    end

    it 'can zoom in (> 1) when content is smaller than the viewport' do
      # content 100×100 in window 200×300: ratios 2 and 3 → min = 2
      expect(fit_zoom(100, 100, 200, 300)).to eq(2.0)
    end

    it 'returns nil when content width is zero (avoids division by zero)' do
      expect(fit_zoom(0, 100, 800, 600)).to be_nil
    end

    it 'returns nil when content height is zero' do
      expect(fit_zoom(100, 0, 800, 600)).to be_nil
    end

    it 'produces the correct precision for non-integer ratios' do
      result = fit_zoom(300, 200, 250, 180)
      # w: 250/300 ≈ 0.8333, h: 180/200 = 0.9 → min = 0.8333
      expect(result).to be_within(0.001).of(250.0 / 300)
    end
  end
end
