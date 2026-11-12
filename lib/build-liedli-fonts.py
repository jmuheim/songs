"""Build the two picture fonts "Liedli Symbole" and "Liedli Hieroglyphen".

Every Latin letter of these fonts is a picture, like Wingdings: a-z and A-Z
(an uppercase letter shows the same picture as its lowercase one), ä ö ü
(and Ä Ö Ü), ß and the digits 0-9. Punctuation is deliberately left out, so
the browser takes it from the next font in the stack. A space (U+0020 and
U+00A0) is kept.

The pictures come from two open fonts, which map them to their own Unicode
code points; this script maps them to the letters instead, keeps only those
glyphs, renames the font and writes it as woff2:

- Liedli Symbole      <- Noto Sans Symbols 2 (pictograms)
- Liedli Hieroglyphen <- Noto Sans Egyptian Hieroglyphs

Both are under the SIL Open Font License 1.1, without a Reserved Font Name, so
the modified fonts may be shipped under a name of their own; "Noto" is a
trademark of Google and is therefore not used in the new names.

Get the sources from https://github.com/google/fonts (ofl/notosanssymbols2/
NotoSansSymbols2-Regular.ttf and ofl/notosansegyptianhieroglyphs/
NotoSansEgyptianHieroglyphs-Regular.ttf), then run:

    pip install fonttools brotli
    python3 lib/build-liedli-fonts.py NotoSansSymbols2-Regular.ttf \\
        NotoSansEgyptianHieroglyphs-Regular.ttf [OUTDIR]

OUTDIR defaults to the song book's style/fonts/. It writes
liedli-symbole-normal-400.woff2 and liedli-hieroglyphen-normal-400.woff2 and
checks them. The same sources give the same files.
"""

import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont, newTable
from fontTools.ttLib.tables._c_m_a_p import CmapSubtable

# The letters each font maps, in this order: a-z, then ä ö ü ß, then 0-9.
CHARS = 'abcdefghijklmnopqrstuvwxyzäöüß0123456789'

# Source code point for each character in CHARS (the comment names the
# picture, and why it fits the letter where there is a reason).
SYMBOLE = [
    0x2708,   # a  airplane
    0x1F426,  # b  bird
    0x1F408,  # c  cat
    0x1F415,  # d  dog
    0x1F441,  # e  eye
    0x1F41F,  # f  fish
    0x1F56D,  # g  ringing bell (Glocke)
    0x2665,   # h  black heart suit
    0x2744,   # i  snowflake (ice)
    0x1F579,  # j  joystick
    0x265A,   # k  black chess king (König)
    0x1F512,  # l  lock
    0x1F39C,  # m  beamed musical notes
    0x1F31C,  # n  moon with face (Nacht)
    0x26BD,   # o  soccer ball
    0x1F336,  # p  hot pepper (Peperoni)
    0x265B,   # q  black chess queen
    0x1F3CE,  # r  racing car
    0x2600,   # s  black sun with rays (Sonne)
    0x260E,   # t  black telephone
    0x2602,   # u  umbrella
    0x270C,   # v  victory hand
    0x2601,   # w  cloud (Wolke)
    0x2702,   # x  black scissors
    0x1F44D,  # y  thumbs up (yes)
    0x26A1,   # z  high voltage (Zickzack)
    0x2660,   # ä  black spade suit
    0x2663,   # ö  black club suit
    0x2666,   # ü  black diamond suit
    0x2603,   # ß  snowman (Schneemann)
    0x2605,   # 0  black star
    0x1F54A,  # 1  dove of peace
    0x2615,   # 2  hot beverage
    0x2618,   # 3  shamrock
    0x265E,   # 4  black chess knight
    0x270B,   # 5  raised hand (five fingers)
    0x1F3E0,  # 6  house
    0x1F5DD,  # 7  old key
    0x1F3C6,  # 8  trophy
    0x2794,   # 9  heavy wide-headed rightwards arrow
]

# Mostly the "alphabet" of Egyptian one-consonant signs (Gardiner numbers),
# the way children's books spell names in hieroglyphs; 0 is nfr, which Egyptian
# scribes wrote for a zero balance, 1-9 are the numeral strokes.
HIEROGLYPHEN = [
    0x1313F,  # a  G001 Egyptian vulture (3)
    0x130C0,  # b  D058 foot (b)
    0x133A1,  # c  V031 basket with handle (k)
    0x130A7,  # d  D046 hand (d)
    0x1316D,  # e  G039 pintail duck (Ente)
    0x13191,  # f  I009 horned viper (f)
    0x133BC,  # g  W011 jar stand (g)
    0x1339B,  # h  V028 twisted wick (h)
    0x131CB,  # i  M017 reed leaf (i)
    0x13193,  # j  I010 cobra (dj)
    0x131A3,  # k  L001 scarab (Käfer)
    0x130ED,  # l  E023 lion (rw, l)
    0x13153,  # m  G017 owl (m)
    0x13216,  # n  N035 water ripple (n)
    0x13362,  # o  V001 coil of rope
    0x132AA,  # p  Q003 stool (p)
    0x1320E,  # q  N029 hill slope (q)
    0x1308B,  # r  D021 mouth (r)
    0x132F4,  # s  S029 folded cloth (s)
    0x133CF,  # t  X001 bread loaf (t)
    0x13171,  # u  G043 quail chick (w, u)
    0x132F9,  # v  S034 ankh
    0x13080,  # w  D010 eye of Horus (wedjat)
    0x1340D,  # x  Aa001 placenta (x)
    0x131CC,  # y  M017A two reed leaves (y)
    0x13283,  # z  O034 door bolt (z)
    0x13143,  # ä  G005 falcon
    0x1319B,  # ö  K001 fish
    0x131F3,  # ü  N005 sun
    0x13000,  # ß  A001 seated man
    0x13124,  # 0  F035 heart and windpipe (nfr)
    0x133FA,  # 1  Z015 one stroke
    0x133FB,  # 2  Z015A two strokes
    0x133FC,  # 3  Z015B three strokes
    0x133FD,  # 4  Z015C four strokes
    0x133FE,  # 5  Z015D five strokes
    0x133FF,  # 6  Z015E six strokes
    0x13400,  # 7  Z015F seven strokes
    0x13401,  # 8  Z015G eight strokes
    0x13402,  # 9  Z015H nine strokes
]

FONTS = [
    dict(family='Liedli Symbole', ps='LiedliSymbole-Regular',
         file='liedli-symbole-normal-400.woff2', picks=SYMBOLE,
         source='Noto Sans Symbols 2'),
    dict(family='Liedli Hieroglyphen', ps='LiedliHieroglyphen-Regular',
         file='liedli-hieroglyphen-normal-400.woff2', picks=HIEROGLYPHEN,
         source='Noto Sans Egyptian Hieroglyphs'),
]

SPACES = (0x20, 0xA0)


def char_map(picks):
    """Target code point -> source code point, upper case included."""
    assert len(picks) == len(CHARS) == len(set(picks)), 'one picture per char'
    out = {}
    for ch, src in zip(CHARS, picks):
        out[ord(ch)] = src
        if ch.upper() != ch and len(ch.upper()) == 1:  # not ß -> SS
            out[ord(ch.upper())] = src
    for sp in SPACES:
        out[sp] = sp
    return out


def build(spec, source_path, outdir):
    # Keep the source's timestamp, so the same sources give the same file.
    font = TTFont(source_path, recalcTimestamp=False)
    src_cmap = font.getBestCmap()
    mapping = char_map(spec['picks'])
    missing = sorted({s for s in mapping.values() if s not in src_cmap})
    if missing:
        sys.exit(f"{spec['source']} lacks {', '.join(f'U+{c:04X}' for c in missing)}")
    target = {cp: src_cmap[src] for cp, src in mapping.items()}

    options = subset.Options()
    options.layout_features = []
    options.hinting = False
    options.notdef_outline = True
    options.name_IDs = ['*']
    options.name_languages = ['*']
    options.glyph_names = True
    options.drop_tables += ['GSUB', 'GPOS', 'GDEF', 'DSIG']
    subsetter = subset.Subsetter(options)
    subsetter.populate(glyphs=sorted(set(target.values())))
    subsetter.subset(font)

    # The new cmap: letters to pictures (format 4, BMP only, both platforms).
    cmap = newTable('cmap')
    cmap.tableVersion = 0
    cmap.tables = []
    for platform, encoding in ((0, 3), (3, 1)):
        sub = CmapSubtable.newSubtable(4)
        sub.platformID, sub.platEncID, sub.language = platform, encoding, 0
        sub.cmap = dict(target)
        cmap.tables.append(sub)
    font['cmap'] = cmap

    os2 = font['OS/2']
    os2.usFirstCharIndex = min(target)
    os2.usLastCharIndex = max(target)
    os2.recalcUnicodeRanges(font)
    os2.ulCodePageRange1, os2.ulCodePageRange2 = 1, 0  # Latin 1
    os2.achVendID = 'UKWN'
    os2.recalcAvgCharWidth(font)

    rename(font, spec)
    font.flavor = 'woff2'
    path = os.path.join(outdir, spec['file'])
    font.save(path)
    return path


def rename(font, spec):
    name = font['name']
    copyright_ = name.getDebugName(0)
    designer = name.getDebugName(9)
    version = font['head'].fontRevision
    license_ = name.getDebugName(13)
    license_url = name.getDebugName(14)
    family, ps = spec['family'], spec['ps']
    name.names = []
    records = {
        0: copyright_,
        1: family,
        2: 'Regular',
        3: f'{version:.3f};UKWN;{ps}',
        4: f'{family} Regular',
        5: f'Version {version:.3f}',
        6: ps,
        9: designer,
        10: (f"Modified version of {spec['source']}: its pictures mapped to "
             'the Latin letters and digits, everything else removed.'),
        13: license_,
        14: license_url,
    }
    for name_id, text in records.items():
        if text:
            name.setName(text, name_id, 3, 1, 0x409)


def check(path, spec):
    font = TTFont(path)
    cmap = font.getBestCmap()
    glyf = font['glyf']
    for ch in 'aAzä7 \u00a0':
        glyph = cmap.get(ord(ch))
        assert glyph, f'{spec["family"]}: {ch!r} is not mapped'
        g = glyf[glyph]
        if ch.isspace():
            assert font['hmtx'][glyph][0] > 0, 'space without advance'
        else:
            assert g.numberOfContours != 0, f'{ch!r} -> {glyph} has no outline'
    assert cmap[ord('A')] == cmap[ord('a')] and cmap[ord('Ä')] == cmap[ord('ä')]
    for ch in CHARS:
        assert glyf[cmap[ord(ch)]].numberOfContours != 0, ch
    assert not any(c in cmap for c in map(ord, '.,!?;:-')), 'punctuation mapped'
    print(f"{path}: {font['name'].getDebugName(4)}, {len(cmap)} code points, "
          f'{len(font.getGlyphOrder())} glyphs, {os.path.getsize(path)} bytes')


def main(argv):
    if len(argv) not in (3, 4):
        sys.exit(__doc__)
    outdir = argv[3] if len(argv) == 4 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'style', 'fonts')
    for spec, source in zip(FONTS, argv[1:3]):
        check(build(spec, source, outdir), spec)


if __name__ == '__main__':
    main(sys.argv)
