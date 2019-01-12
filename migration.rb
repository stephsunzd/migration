require 'erb'

module Migration
  def self.generate_import_file(codes, source_url, items)
    language_code = codes[:language]
    country_code = codes[:country]

    posts_erb = File.open('templates/posts.xml.erb').read
    posts_erb = ERB.new(posts_erb)

    out_file = File.new("import_files/posts_#{country_code}.xml", "w")
    out_file.puts(posts_erb.result(binding))
    out_file.close
  end
end
