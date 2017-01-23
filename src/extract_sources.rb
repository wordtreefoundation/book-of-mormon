#!/usr/bin/env ruby

require 'find'
require 'optparse'
require 'uri'
require 'yaml'

begin
  require 'state_machine'
rescue LoadError
  abort "Aborting! Must have the gem state_machine installed!"
end

class Hash
  def stringify_keys
    map {|k, v| [k.to_s, v] }.to_h
  end
end

class ScriptureVerse < Struct.new(:book, :chapter, :verse, :text, :sources)
  VERSE_RE = /\*([\w\s]+) (\d+):(\d+)\* (.*)/

  def self.from_line(line, sources)
    book, chapter, verse, text = line.match(VERSE_RE).captures
    new(book, chapter.to_i, verse.to_i, text, sources)
  end

  alias_method :old_to_h, :to_h

  def to_h
    old_to_h.stringify_keys.merge({'sources' => self.sources.map(&:to_h)})
  end
end

class BibleVerseDetails < Struct.new(:book, :chapter, :start_verse, :end_verse, :relevant_text, :url)
  KING_JAMES_ONLINE_BASE = "http://www.kingjamesbibleonline.org/"
  CHAPTER_RE = %r!#{KING_JAMES_ONLINE_BASE}([\-\w]+)-Chapter-(\d+)!
  CHAPTER_VERSE_RE = %r!#{KING_JAMES_ONLINE_BASE}([\-\w]+)-(\d+)-(\d+)/!
  BIBLE_VERSE_RE = %r{:([\d\-]+)\]\Z}

  # takes all the BibleVerse's information and sets the appropriate url to the
  # online King James Bible.
  # book should already be hyphenated
  def self.generate_url(hyphenated_book, chapter, start_verse, end_verse)
    single_verse = (start_verse == end_verse)
    details = [hyphenated_book, single_verse ? chapter : "Chapter-#{chapter}"]
    details << start_verse if single_verse
    url = [KING_JAMES_ONLINE_BASE, details.join("-")].join
    url << "/"
  end

  def self.from_source(source)
    if md = CHAPTER_RE.match(source.url)
      hyphenated_book, chapter_str = md.captures
      if md = BIBLE_VERSE_RE.match(source.reference)
        start_verse, end_verse = md.captures.first.split("-").map(&:to_i)
      end
    elsif md = CHAPTER_VERSE_RE.match(source.url)
      hyphenated_book, chapter_str, verse_str = md.captures
      start_verse = verse_str.to_i
    end
    end_verse ||= start_verse
    url = generate_url(hyphenated_book, chapter_str, start_verse, end_verse)
    new(hyphenated_book.gsub('-', ' '), chapter_str.to_i, start_verse, end_verse, source.text, url)
  end

  alias_method :old_to_h, :to_h
  def to_h
    old_to_h.stringify_keys
  end

end

class Source < Struct.new(:text, :reference, :url, :bible_verse_details)
  REFERENCES_START_WITH = '[small]#'
  REFERENCES_END_WITH = '#'

  class << self
    def strip_small_format_string(reference)
      if reference.end_with?('#')
        reference.sub(REFERENCES_START_WITH, '')[0...-1]
      else
        reference
      end
    end

    def is_reference_line?(line)
      line.start_with?(REFERENCES_START_WITH) && line.end_with?(REFERENCES_END_WITH)
    end

    def many_from_lines(lines)
      reference_indices = lines.map.with_index {|line, index| index if is_reference_line?(line) }.compact

      if reference_indices.empty?
        # This is a footnote.  It only has text (no references).
        [Source.new(lines.join(" "))]
      else
        start_index = 0
        sources = []
        reference_indices.each do |reference_index|
          text = lines[start_index...reference_index].join
          reference = strip_small_format_string(lines[reference_index])
          source = new(text, reference)
          if source.url.start_with?(BibleVerseDetails::KING_JAMES_ONLINE_BASE)
            source.bible_verse_details = BibleVerseDetails.from_source(source)
          end
          sources << source
          start_index = reference_index + 1
        end
        sources
      end
    end
  end

  # A source with no reference is considered a 'footnote'
  def is_a_footnote?
    self.reference.nil? && self.url.nil?
  end

  def initialize(*args)
    super(*args)
    if self.reference
      # remove any ascii doc tag on the end of the url
      self.url = URI.extract(self.reference).first.sub(/\[.*?\]\Z/, '')
    end
  end

  alias_method :old_to_h, :to_h
  def to_h
    details_hash = self.bible_verse_details ? {'bible_verse_details' =>  self.bible_verse_details.to_h} : {}
    old_to_h.stringify_keys.merge(details_hash)
  end

end

class Parser
  IS_VERSE_RE = /\*.+\*/
  END_MARGIN = '{% endmargin %}'
  START_MARGIN_RE = /{% margin( \d)? ?%}/
  SOURCE_DELIMITER = "____"
  ASCII_DOC_EXT = ".adoc"

  attr_accessor :scripture_verses

  class << self
    # parses a file and returns an array of scripture_verses
    def parse_file(filename)
      parser = new
      IO.foreach(filename) {|line| parser.parse(line.chomp) }
      parser.scripture_verses
    end

    # returns a single array of scripture_verses from all the files.
    def parse_files(filenames)
      filenames.flat_map {|filename| parse_file(filename) }
    end

    # parses all files in directory ending in ASCII_DOC_EXT (recursively) and
    # returns array of scripture_verses (because not everyone uses zsh for simple
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
    @scripture_verses = []
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
          if @source_lines.size > 0 && @source_lines.any? {|line| !line.strip.empty? }
            @sources.push(*Source.many_from_lines(@source_lines))
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
          @scripture_verses << ScriptureVerse.from_line(line, @sources || [])
          @sources = []
        end
      end
    end

    state :in_source do
      def parse(line)
        if line == SOURCE_DELIMITER
          @sources.push(*Source.many_from_lines(@source_lines))
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
  opts = {}
  parser = OptionParser.new do |op|
    script = File.basename(__FILE__)
    op.banner = "usage: #{script} [OPTS] <file>.adoc ..."
    op.separator "usage: #{script} [OPTS] <directory>"
    op.separator "  the directory invocation will process all adoc files in dir"
    op.separator ""
    op.separator "to parse entire book of mormon from the repo's base dir, run:"
    op.separator "  ./src/#{script} content > bom.yml"
    op.separator ""
    op.separator "options: "
    op.on("--structs", "Output yaml coded as ruby structs.",
     "(Default is to emit YAML readable by any",
     "language's YAML parser w/o dependencies.) """
    ) {|v| opts[:structs] = v }
  end
  parser.parse!

  if ARGV.size == 0
    puts parser
      exit
  end

  scripture_verses =
    if File.directory?(ARGV.first)
      Parser.parse_directory(ARGV.first)
    else
      Parser.parse_files(ARGV)
    end

  objects_prepped_for_yaml_output =
    if opts[:structs]
      scripture_verses
    else
      scripture_verses.map(&:to_h)
    end

  puts objects_prepped_for_yaml_output.to_yaml
end
