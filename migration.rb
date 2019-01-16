require 'csv'
require 'erb'
require 'open-uri'
require 'nokogiri'

module Migration
  module_function

  TAG_DOMAIN = 'filter_tag_blog'
  MAX_POSTS_PER_IMPORT_FILE = 60

  def csv_to_item(country_code)
    headers = []
    items = []

    CSV.foreach("metadata_files/#{country_code}.csv") do |row|
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
          item['item_tags'] = []

          value.split(',').each do |tag_name|
            item[headers[index]] << {
              domain: TAG_DOMAIN,
              name: tag_name,
              nicename: tag_name.downcase.gsub(/\W/, '-')
            }
          end unless value.nil?
        else
          item[headers[index]] = value
        end
      end

      item['pubDate'] = timestamp_to_pubDate(item['item_published_at'])

      items << item
    end

    return items
  end

  def generate_import_files(codes, source_url)
    items = csv_to_item(codes[:country])
    puts '# CSV has been uploaded'

    items = scrape_posts(items)

    posts_erb = File.open('templates/posts.xml.erb').read
    posts_erb = ERB.new(posts_erb)

    num_import_files = items.length / MAX_POSTS_PER_IMPORT_FILE + 1

    (1..num_import_files).each do |file_index|
      import_file_path = "import_files/posts_#{codes[:country]}_#{file_index}.xml"
      items_set_start = (file_index - 1) * MAX_POSTS_PER_IMPORT_FILE
      items_set_end = num_import_files == file_index ? -1 : file_index * MAX_POSTS_PER_IMPORT_FILE - 1
      items_set = items[items_set_start..items_set_end]

      out_file = File.new(import_file_path, "w")
      out_file.puts(posts_erb.result(binding))
      out_file.close

      puts "# #{import_file_path} has been created"
    end
  end

  def scrape_posts(items)
    items.each do |item|
      puts "# Scraping #{item['item_url']}"

      item = scrape_post(item)
    end

    return items
  end

  def scrape_post(item)
    post = Nokogiri::HTML(open(item['item_url']))

    post_content = post.css('.entry').first.inner_html
    item['post_content'] = post_content.gsub(/<blockquote class="author">.*?<\/blockquote>/m, '')

    if item['author_first_name'].nil? && item['author_last_name'].nil? && !post.css('span.author').empty?
      author = post.css('span.author').first.content.split(' ')

      item['author_first_name'] = author[0]
      item['author_last_name'] = author[1..-1].join(' ')
    end

    return item
  end

  def timestamp_to_pubDate(timestamp)
    pubDate = {
      year: timestamp[0..3].to_i,
      month: timestamp[5..6].to_i,
      day: timestamp[8..9].to_i,
      time: timestamp[11..18]
    }

    pubDate[:date] = Date.new(pubDate[:year], pubDate[:month], pubDate[:day])

    return "#{pubDate[:date].strftime('%a, %d %b %Y')} #{pubDate[:time]} +0000"
  end
end
