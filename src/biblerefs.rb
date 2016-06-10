require 'bomdb'
require 'kj'

$bible = Kj::Bible.new

def bom_verse(book, chapter, verse)
  BomDB::Query.new(
    edition: '1830',
    range: "#{book} #{chapter}:#{verse}",
  )
end

def find_bom_file(book, chapter)
  "../#{book.downcase.gsub(' ', '')}/chapter_#{'%02d' % chapter}.adoc"
end

def inserted_before_verse(book, chapter, verse, text, highlight=true)
  file = find_bom_file(book, chapter)
  file_content = File.read(file)
  replacement = highlight ? "#{text}\n\\1 [orange-background]#\\2#" : "#{text}\n\\1 \\2"
  file_content.sub(/^(\*#{book} #{chapter}:#{verse}\*) (.*)$/, replacement)
end

def kjv_margin_quote(book, chapter, verse)
  body = $bible.book(book).chapter(chapter).verse(verse).text
  pericope = "#{book} #{chapter}:#{verse}"
  link = "http://www.kingjamesbibleonline.org/#{book}-Chapter-#{chapter}/"
  "{% marginal %}\n****\n*Quote* #{body}\n\nKJV Bible, 1769, #{link}[#{pericope}]\n****\n{% endmarginal %}\n\n"
end

blank_verse_format = lambda{ |b,c,v| '' }

BomDB.db[:refs].
  where(:ref_name => 'Bible-NT').
  join(:verses, :verse_id => :verse_id).
  join(:books, :book_id => :book_id).
  each do |r|
    # asterisk = r[:ref_is_quotation] ? '*' : ''

    bible_pericope = "#{r[:ref_book]} #{r[:ref_chapter]}:#{r[:ref_verse]}"
    bom_pericope = "#{r[:book_name]} #{r[:verse_chapter]}:#{r[:verse_number]}"
    puts "#{bible_pericope} => #{bom_pericope}"

    begin
      file = find_bom_file(r[:book_name], r[:verse_chapter])
      puts file

      # Put a marginal quotation of the bible reference next to the corresponding Book of Mormon verse
      transformed = inserted_before_verse(r[:book_name], r[:verse_chapter], r[:verse_number],
        kjv_margin_quote(r[:ref_book], r[:ref_chapter], r[:ref_verse]))

      # Save the chapter with the added biblical reference
      File.open(file, "w") do |f|
        f.write(transformed)
      end
    rescue Kj::Iniquity => e
      # skip it
      puts "Skipping due to error (#{e})"
    end
  end

