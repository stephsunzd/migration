require 'csv'
require 'erb'

module Migration
  def self.csv_to_item(language_code)
    headers = []
    items = []

    CSV.foreach("metadata_files/#{language_code}.csv") do |row|
      if headers.empty?
        headers.replace(row)
        next
      end

      item = {}

      row.each_with_index do |value, index|
        case headers[index]
        when 'item_hidden'
          item['post_status'] = value === 'TRUE' ? 'draft' : 'publish'
        when 'item_tags'
          item[headers[index]] = []

          value.split(',').each do |tag_name|
            item[headers[index]] << {
              name: tag_name
            }
          end
        else
          item[headers[index]] = value
        end
      end

      items << item
    end

    return items
  end

  def self.generate_import_file(codes, source_url)
    items = self.csv_to_item(codes[:language])
    items = self.scrape_page_data(items)

    posts_erb = File.open('templates/posts.xml.erb').read
    posts_erb = ERB.new(posts_erb)

    out_file = File.new("import_files/posts_#{codes[:country]}.xml", "w")
    out_file.puts(posts_erb.result(binding))
    out_file.close
  end

  def self.scrape_page_data(items)
    items.each do |item|
      if item['author_first_name'].nil? && item['author_last_name'].nil?
        item['author_first_name'] = 'Andrew'
        item['author_last_name'] = 'Gori'
      end
    end

    return items
  end
end
