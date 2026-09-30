# Chord alignment: column tabs → inline `[Chord]` notation

Source tabs typically look like this — a chord line sitting above a lyric line, where each chord's horizontal position marks the exact syllable it changes on:

```
C         G      C
Lueget do aben a See!
```

This project's format puts the chord inline instead, right before the syllable it belongs to:

```
[C] Lueget do [G] aben a [C] See!
```

Getting from one to the other is column arithmetic plus judgment about word boundaries. Below is the method, illustrated with real lines from `content/songs/Lueget Vo Bärg Und Tal (Traditionell).md`.

## The core move: map each chord's column to a word start

Index both lines by character position (1-based is fine, just be consistent). For each chord in the chord line, find its column, then find which word in the lyric line starts nearest that column.

```
C         G      C
Lueget do aben a See!
```

- `C` at column 1 → `Lueget` starts at column 1 → exact match.
- `G` at column 11 → `aben` starts at column 11 → exact match.
- `C` at column 18 → `See!` starts at column 18 → exact match.

Result: `[C] Lueget do [G] aben a [C] See!`

Real-world tabs are rarely typed with perfect precision, though — expect chords to land 1-2 characters off from the "true" word start. Round to the nearest word rather than taking the column literally. A one-character offset is noise, not intent.

## Whole-word attach vs. mid-word fuse

Once you know which word a chord belongs to, decide how to attach it:

**Whole-word attach** (the common case): the chord sits before the word as its own bracketed token, with normal spacing on both sides — exactly like inserting a new word into the sentence.

```
de [G] Bärge no [C] stoht
```

**Mid-word fuse** (only when the chord genuinely lands inside a single token, at a real internal boundary — a contraction, a compound word, or an English word split mid-syllable): no spaces at all, fused exactly at that character position.

```
[C] flieht scho de Sunne[G]strahl     ← compound word: Sunne + strahl
Heimezue wändet sich s'[G]Veh.        ← contraction: s' + Veh
[C] Loset, wie d'[F]Glogge, die [C] schöne,   ← contraction: d' + Glogge
Fründli [C] vom [F] Moos us er[C]töne.        ← inside one word: er + töne
```

How to tell which case you're in: if the chord's column falls right at or ~1 char from where a *space-delimited token* begins, it's whole-word. If it falls 2+ characters into a token, but at a point where the token is actually two meaningful morphemes glued together (article contraction `d'`/`s'`, a compound noun, a word like `wouldn't`), fuse it there. If a chord seems to land mid-word for no linguistic reason and off by only 1 character, that's almost always ASCII misalignment — round it to the nearest word boundary instead of fusing.

## Dangling chords (no lyric underneath)

Sometimes a chord line has a chord with nothing under it — a passing chord at the end of a line, or a purely instrumental beat between lyric lines. Represent it as its own bracket token, attached where it falls:

```
[C] flieht scho de Sunne[G]strahl. [G7]
```

Here `[G7]` has no word of its own — it's a pickup chord after the line's last word, so it's appended at the end with a leading space, same as any other whole-word attach, just with no word following it.

Multiple dangling chords in a row (e.g. a two-beat instrumental fill) become adjacent bracket tokens: `[Dm] [E]`.

## Repeats that get denser on the second pass

Folk/traditional songs often repeat the same lyric line twice with progressively richer harmony — same words, more passing chords the second time:

```
[C] Oh, wie si [F] d'Gletscher [G] so [C] rot!
[Am] Oh, wie si [Dm] d'Gletscher [G7] so [C] rot!
```

Note the pattern: `Am` is added at the very start (was implicitly still `C`/whatever preceded), the passing chord that used to sit on "d'Gletscher" gets replaced by a new chord (`F`→`Dm`), and the following word ("so") gets a brand-new chord that wasn't there before (`G`, later upgraded to `G7`). This is deliberate — carry these differences over exactly, and if the user later tweaks the first occurrence's chords, mirror the *equivalent* change into every later verse's structurally-matching line rather than copying verse 1 verbatim (word counts and phrasing differ verse to verse, so match by "which word in this verse plays the same structural role," not by literal word position number).

## Line length: split dense lines at their natural pause

Some tabs pack a lot of quick chord changes into one sung line — a turnaround at the end of every phrase, a fill in the middle of a word. Inlining all of them literally can produce a single output line far longer than anything else in the book, and that's a real problem, not just a style nitpick: `style/slide-zoom.js` zooms each *entire slide* to fit its widest line, so one 90-character line shrinks the title and every other line on that slide right along with it.

This happened with `content/songs/Stets in Truure (Rumpelstilz).md`. The raw tab has a turnaround riff (`F C`) at the end of every phrase and a quick `C G` fill mid-word, so a first-pass conversion produced lines like:

```
Oh, wie [Am] wohl isch's einem [Dm] Mönsche, wo nid [C] [G] weiss, was Liebi [C] heisst [F] [C]
```

96 characters — while nothing else in the whole songbook with 3+ chords on one line exceeds ~70. The fix wasn't to touch the chords, just where the *line* breaks. The comma right after "Mönsche," is exactly the spot the original ASCII tab already left a wide gap for (a breath), so that's where the split goes — with the trailing dangling `[F] [C]` turnaround moved onto the second half rather than left dangling off the first:

```
Oh, wie [Am] wohl isch's einem [Dm] Mönsche,
wo nid [C] [G] weiss, was Liebi [C] heisst [F] [C]
```

Two short lines, same stanza — no blank line between them, because a blank line in this format means an actual new stanza or repeat, not a wrap. Do this check on every line that has 3+ chords before calling a conversion done: compare against `awk -F'[][]' '{ n = (NF-1)/2; if (n >= 3) print length($0), n }'` run over a couple of existing songs.

## Sanity check before finishing

For every chord bracket in the source chord line, there should be exactly one matching `[Chord]` token in your output line — none invented, none dropped. If the counts don't match, re-check your column mapping before moving on.
