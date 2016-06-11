# Geek Notes

## Git Repository

This gitbook is available as a git repository at https://github.com/wordtreefoundation/book-of-mormon

## Generating the Text

If you'd like to create a similar project and have some knowledge of programming and the Linux command-line, you may be interested in the following.

You can generate the source text of this book in its unannotated form (i.e. as a series of text files) using the `gen.sh` command included in this repository. Here is a basic outline of the steps necessary to generate the text files:

* Install Ruby
* Install [bomdb](https://github.com/wordtreefoundation/bomdb), a command-line tool for querying, diffing, and generating portions of text from the Book of Mormon
* Run the `gen.sh` command in this repository

## Plugins

This gitbook uses the following plugins:

* expandable-chapters
* callouts
* emphasize

We're considering using these plugins as well:

* injection / addcssjs
* image-captions
* forkmegithub / github
* bibtex-citation-michael
* richquotes
* infinitescroll
* toc
