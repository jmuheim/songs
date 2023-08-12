# My Songs

This is a repository of beloved songs that I can perform on guitar. They are written in Markdown syntax.

To make it easy for people to join singing, I created a little script that generates:

- a website song book that can be controlled similar to an app, e.g. using swipe gestures (left/right to change songs, up/down to go through song parts)
- a beautiful printable PDF version of the same song book

A recent version of the song book can be visited here: [josh.ch/songs](https://josh.ch/songs).

## Usage

Simply add more songs to `content/songs`. Then fire up a console, go to this folder and run the following command: `$ ./song-book-builder.rb`.

You need Ruby installed. And the script file needs to be executable (`$ chmod +x song-book-builder.rb`).

The command will run for quite some time, as PDF generation is slow.

## TODOs

- Add switch to disable PDF generation when running script
