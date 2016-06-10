require 'fileutils'

def asciidoc_path(path)
	path.sub(/\.md$/, ".adoc")
end

def convert_to_asciidoc(content)
	content.gsub("**", "*")
end

%w(1nephi 2nephi 3nephi 4nephi alma enos ether helaman jacob jarom mormon moroni mosiah omni wom).each do |book|
	Dir.glob(File.join("..", book, "*.md")) do |path|
		begin
			content = File.read(path)
			File.open(asciidoc_path(path), "w") do |file|
				file.write(convert_to_asciidoc(content))
			end
		rescue => e
			puts "Error converting #{path}: #{e}"
		else
			FileUtils.rm(path)
		end
	end
end
