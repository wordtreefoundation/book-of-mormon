#!/usr/bin/env ruby

require 'state_machine'

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

  def self.from_lines(lines=[])
    lines.select! {|line| line.size > 0 }
    if lines.size == 1 and !lines.first.start_with?(REFERENCES_START_WITH)
      # it's a footnote
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
  END_MARGIN = '{% endmargin %}'
  START_MARGIN_RE = /{% margin( \d)? ?%}/
  SOURCE_DELIMITER = "____"

  attr_accessor :verses

  def initialize
    @verses = []
    @source_lines = []
    super()
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
        elsif line.size > 0
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
    puts "usage: #{File.basename(__FILE__)} <file>.adoc ..."
    exit
  end

  parser = Parser.new

  ARGV.each do |filename|
    next if filename.include?("external")
    IO.foreach(filename) do |line|
      line.chomp!
      parser.parse(line)
    end
  end
  parser.verses.each do |verse|
    p verse
    #puts verse.book + [verse.chapter, verse.verse].join(":")
    #p verse.sources
  end
end
