# My Songs

This is a repository of beloved songs that I can perform on guitar. They are written in Markdown syntax.

To make it easy for people to join singing, I created a little script that generates:

- a website song book that can be controlled similar to an app, e.g. using swipe gestures (left/right to change songs, up/down to go through song parts)
- a beautiful printable PDF version of the same song book

A recent version of the song book can be visited here: [josh.ch/songs](https://josh.ch/songs).

## Installation

- You need [Ruby](https://www.ruby-lang.org/) installed (I have version `3.0`)
- You need [Pandoc](https://pandoc.org/) installed: `$ brew install pandoc` (I have version `3.1.2`)
- We use [DeckTape](https://github.com/astefanutti/decktape) to generate PDFs, so install it: `$ npm install -g decktape`
- Last but not least, the script file needs to be executable: `$ chmod +x song-book-builder.rb`

## Adding songs

Simply add more songs to `content/songs`.

## Compile HTML and PDF

Run the following command: `$ ./song-book-builder.rb`.

PDF generation is slow and skipped by default. Pass `--pdf` to include it:

```
$ ./song-book-builder.rb --pdf
```
