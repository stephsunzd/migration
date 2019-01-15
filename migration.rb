require 'csv'
require 'erb'
require 'open-uri'
require 'nokogiri'

module Migration
  module_function

  def csv_to_item(language_code)
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

  def generate_import_file(codes, source_url)
    items = csv_to_item(codes[:language])
    items = scrape_posts(items)

    posts_erb = File.open('templates/posts.xml.erb').read
    posts_erb = ERB.new(posts_erb)

    out_file = File.new("import_files/posts_#{codes[:country]}.xml", "w")
    out_file.puts(posts_erb.result(binding))
    out_file.close
  end

  def scrape_posts(items)
    items.each do |item|
      item = scrape_post(item)
    end

    return items
  end

  def scrape_post(item)
    post = Nokogiri::HTML(open(item['item_url']))

    puts post.css('.entry').first.methods

    if item['author_first_name'].nil? && item['author_last_name'].nil?
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
