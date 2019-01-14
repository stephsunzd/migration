require 'erb'

module Migration
  def self.generate_import_file(codes, source_url, items)
    posts_erb = File.open('templates/posts.xml.erb').read
    posts_erb = ERB.new(posts_erb)

    out_file = File.new("import_files/posts_#{codes[:country]}.xml", "w")
    out_file.puts(posts_erb.result(binding))
    out_file.close
  end
end
