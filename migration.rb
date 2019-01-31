require 'csv'
require 'erb'
require 'open-uri'
require 'nokogiri'
require_relative 'util'
require_relative 'constants'

module Migration
  module_function

  def csv_to_items(country_code)
    headers = []
    items = []

    CSV.foreach("metadata_files/#{country_code}.csv") do |row|
      if headers.empty?
        headers.replace(row)
        next
      end

      # # TODO:
      # resource type map to key (type 2 is webinar)
      # tags - remove category going forward
      # video thing

      item = { Constants::KEYS[:type] => 'post' }

      row.each_with_index do |value, index|
        case headers[index]
        when 'item_tags'
          item['item_tags'] = []

          value.split(',').each do |tag_name|
            Constants::TAG_DOMAINS.each do |tag_domain|
              item['item_tags'] << {
                domain: tag_domain,
                name: tag_name,
                nicename: tag_name.downcase.gsub(/\W/, '-')
              }
            end
          end unless value.nil?
        when Constants::KEYS[:type]
          item[Constants::KEYS[:type]] = value unless value.nil?
        else
          item[headers[index]] = value
        end
      end

      item['post_status'] = 'publish'
      item['pubDate'] = Util.timestamp_to_pubDate(item['item_published_at'])
      item['post_excerpt'] = Util.excerpt(item['item_description'])

      if Util.uberflip_image?(item[Constants::KEYS[:image]])
        image_suffix = Util.image_suffix( open(item[Constants::KEYS[:image]]) )
        image_migrated_name = "#{country_code}-#{item[Constants::KEYS[:type]]}-#{item[Constants::KEYS[:id]]}.#{image_suffix}"
        item[Constants::KEYS[:image]] = "#{Constants::MIGRATED_IMAGES_DIR}#{country_code}/#{image_migrated_name}"
      end

      items << item
    end

    return items
  end

  def generate_import_files(codes, source_url)
    items = csv_to_items(codes[:country])
    puts '# CSV has been uploaded'

    items = scrape_posts(items)

    posts_erb = File.open('templates/posts.xml.erb').read
    posts_erb = ERB.new(posts_erb)

    num_import_files = items.length / Constants::MAX_POSTS_PER_IMPORT_FILE + 1

    (1..num_import_files).each do |file_index|
      import_file_path = "import_files/posts_#{codes[:country]}_#{file_index}.xml"
      items_set_start = (file_index - 1) * Constants::MAX_POSTS_PER_IMPORT_FILE
      items_set_end = num_import_files == file_index ? -1 : file_index * Constants::MAX_POSTS_PER_IMPORT_FILE - 1
      items_set = items[items_set_start..items_set_end]

      out_file = File.new(import_file_path, "w")
      out_file.puts(posts_erb.result(binding))
      out_file.close

      puts "# #{import_file_path} has been created"
    end
  end

  def scrape_posts(items)
    items.each do |item|
      puts "# Scraping #{item[Constants::KEYS[:url]]}"

      item = scrape_post(item)
    end

    return items
  end

  def scrape_post(item)
    return item if item[Constants::KEYS[:url]].nil? || item[Constants::KEYS[:url]].empty?

    item['post_content'] = ''

    begin
      post = Nokogiri::HTML(open(item[Constants::KEYS[:url]]))
    rescue OpenURI::HTTPError => http_error
      puts http_error
    end

    if post.respond_to?(:css)
      post_content = post.css('.entry')

      unless post_content.empty?
        post_content_html = post_content.first.inner_html
        item['post_content'] = post_content_html.gsub(/<blockquote class="author">.*?<\/blockquote>/m, '')

        item['post_excerpt'] = Util.excerpt(post_content.text) if item['post_excerpt'].empty?
      end

      if item['author_first_name'].nil? && item['author_last_name'].nil? && !post.css('span.author').empty?
        author = post.css('span.author').first.content.split(' ')

        item['author_first_name'] = author[0]
        item['author_last_name'] = author[1..-1].join(' ')
      end
    end

    return item
  end
end
