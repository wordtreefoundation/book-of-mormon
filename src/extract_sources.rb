#!/usr/bin/env ruby

require 'state_machine'
require 'find'

Highlight = Struct.new(:color, :text)

Verse = Struct.new(:book, :chapter, :verse, :text, :sources) do
  VERSE_RE = /\*([\w\s]+) (\d+):(\d+)\* (.*)/

  def self.from_line(line, sources)
    book, chapter, verse, text = line.match(VERSE_RE).captures
    new(book, chapter.to_i, verse.to_i, text, sources)
  end
end

Source = Struct.new(:text, :reference) do
  REFERENCES_START_WITH = '[small]#'

  def self.is_footnote(lines)
    lines.size == 1 and !lines.first.start_with?(REFERENCES_START_WITH)
  end

  def self.from_lines(lines=[])
    lines.select! {|line| line.size > 0 }
    if is_footnote(lines)
      Footnote.new(lines[0])
    else
      text = lines[0...-1]
      reference = lines.last
      new(text, reference)
    end
  end
end

Footnote = Struct.new(:text)

class Parser
  IS_VERSE_RE = /\*.+\*/
  END_MARGIN = '{% endmargin %}'
  START_MARGIN_RE = /{% margin( \d)? ?%}/
  SOURCE_DELIMITER = "____"
  ASCII_DOC_EXT = ".adoc"

  attr_accessor :verses

  class << self
    # parses a file and returns an array of verses
    def parse_file(filename)
      parser = new
      IO.foreach(filename) {|line| parser.parse(line.chomp) }
      parser.verses
    end

    # returns a single array of verses from all the files.
    def parse_files(filenames)
      filenames.flat_map {|filename| parse_file(filename) }
    end

    # parses all files in directory ending in ASCII_DOC_EXT (recursively) and
    # returns array of verses (because not everyone uses zsh for simple
    # recursive globs)
    def parse_directory(dir)
      files = []
      Find.find(dir) do |path| 
        Find.prune if File.directory?(path) && File.basename(path)[0] == '.'
        files << path if File.extname(path) == ASCII_DOC_EXT 
      end
      files.sort!
      parse_files(files)
    end
  end

  def initialize
    @verses = []
    @source_lines = []
    super
  end

  state_machine :state, initial: :in_verses do
    event :start_margin do
      transition :in_verses => :in_margin
    end

    event :end_margin do
      transition :in_margin => :in_verses
    end

    event :start_source do
      transition :in_margin => :in_source
    end

    event :end_source do
      transition :in_source => :in_margin
    end

    state :in_margin do
      def parse(line)
        if line == END_MARGIN
          if @source_lines.size > 0
            @sources << Source.from_lines(@source_lines)
            @source_lines = []
          end
          end_margin
        elsif line == SOURCE_DELIMITER
          @source_lines = []
          start_source
        else
          @source_lines << line
        end
      end
    end

    state :in_verses do
      def parse(line)
        if line =~ START_MARGIN_RE
          @sources = []
          start_margin
        elsif line =~ IS_VERSE_RE
          @verses << Verse.from_line(line, @sources || [])
          @sources = []
        end
      end
    end

    state :in_source do
      def parse(line)
        if line == SOURCE_DELIMITER
          @sources << Source.from_lines(@source_lines)
          @source_lines = []
          end_source
        else
          @source_lines << line
        end
      end
    end
  end
end

if __FILE__ == $0
  if ARGV.size == 0
    script = File.basename(__FILE__)
    puts "usage: #{script} <file>.adoc ..."
    puts "usage: #{script} <directory>"
    puts "  the directory invocation will process all adoc files in dir"
    puts ""
    puts "to parse entire book of mormon from the repo's base dir, run:"
    puts "  #{script} content"
    exit
  end

  verses =
    if File.directory?(ARGV.first)
      Parser.parse_directory(ARGV.first)
    else
      Parser.parse_files(ARGV)
    end
  source_to_verse = {}
  verses.each do |verse|
  end
end
