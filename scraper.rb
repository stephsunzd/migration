require 'csv'
require 'erb'
require 'open-uri'
require 'nokogiri'
require_relative 'util'
require_relative 'constants'

module Scraper
  module_function

  def scrape_posts(country_code)
    headers = []
    items = []

    CSV.foreach("smartling_sitemaps/#{country_code}.csv").with_index do |row, index|
      url = row.first
      item = new_item(url, (Constants::SMARTLING_ID_START + index).to_s)
      item = scrape_post(item)


      puts "# Post #{url} has been normalized"

      items << item
    end

    return items
  end

  def generate_import_files(codes, source_url)
    items = scrape_posts(codes[:country])

    posts_erb = File.open('templates/posts.xml.erb').read
    posts_erb = ERB.new(posts_erb)

    num_import_files = items.length / Constants::MAX_POSTS_PER_IMPORT_FILE + 1

    (1..num_import_files).each do |file_index|
      import_file_path = "import_files/sl_posts_#{codes[:country]}_#{file_index}.xml"
      items_set_start = (file_index - 1) * Constants::MAX_POSTS_PER_IMPORT_FILE
      items_set_end = num_import_files == file_index ? -1 : file_index * Constants::MAX_POSTS_PER_IMPORT_FILE - 1
      items_set = items[items_set_start..items_set_end]

      out_file = File.new(import_file_path, "w")
      out_file.puts(posts_erb.result(binding))
      out_file.close

      puts "# #{import_file_path} has been created"
    end
  end

  def scrape_post(item)
    return item if item[Constants::KEYS[:url]].nil? || item[Constants::KEYS[:url]].empty?

    begin
      post = Nokogiri::HTML(
        open(
          Util.clean_url(
            item[Constants::KEYS[:url]]
          )
        )
      )
    rescue OpenURI::HTTPError => http_error
      puts http_error
    end

    if post.respond_to?(:css)
      postmeta = {
        title: '',
        content: '',
        image: '',
        excerpt: '',
        tags: [],
      }

      post_description = post.css('meta[name="description"]')
      item['item_description'] = post_description.first.attribute('content').value unless post_description.empty?
      item['post_excerpt'] = ''

      case item[Constants::KEYS[:type]]
      when 'customer_lp'
        postmeta[:title] = post.css('.customer-header-box h3')
        postmeta[:excerpt] = post.css('.customer-header-box h1')
        postmeta[:content] = post.css('#story-body-content')
        postmeta[:image] = post.css('.customer-hero-background')
        postmeta[:tags] = post.css('.customer-header-box .tags a')

        item['logo'] = post.css('.stats-customer-logo img').first.attribute('src').value

        item['item_seo_description'] = item['item_description']

        item[Constants::KEYS[:stats]] = get_stats(post.css('#stats-box li'))
      end

      unless postmeta[:title].empty?
        item['item_title'] = postmeta[:title].first.text
      end

      unless postmeta[:excerpt].empty?
        item['post_excerpt'] = postmeta[:excerpt].first.text
      end

      unless postmeta[:content].empty?
        post_content_html = postmeta[:content].first.inner_html
        item['post_content'] = post_content_html.gsub(Constants::SMARTLING_CONTENT_REGEX, '')

        if item[Constants::KEYS[:type]].eql?('customer_lp')
          item['post_content'] += '</div></div>'

          post_quote = post.css('.quote')

          item['post_content'] += "<section class=\"quote\">
#{post_quote.first.inner_html}
</section>" unless post_quote.empty?
        end

        item['post_excerpt'] = Util.excerpt(postmeta[:content].text) if item['post_excerpt'].empty?
      end

      unless postmeta[:image].empty?
        item[Constants::KEYS[:image]] = if postmeta[:image].attribute('src').nil?
          postmeta[:image].attribute('style').value.scan(/url\((.+?)\)/).first.first
        else
          postmeta[:image].attribute('src').value
        end

        item['item_title'] = postmeta[:title].first.text
      end

      item['item_tags'] = postmeta[:tags].map do |tag|
        Constants::TAG_DOMAINS[item[Constants::KEYS[:type]]].map do |domain|
          {
            domain: domain,
            name: tag.text,
            nicename: tag.attribute('href').value[24..-1]
          }
        end
      end.flatten
    end # end if post.respond_to?(:css)

    item['pubDate'] = Util.timestamp_to_pubDate(item['item_published_at']) unless item['item_published_at'].nil?

    return item
  end

  def get_stats(nodes)
    Util.serialize(
      nodes.select do |node|
        node.children.search('img').size.zero?
      end.map do |node|
        spans = node.children.search('span')

        {
          'customer-stat-title' => spans.first.text,
          'customer-stat-value' => spans.last.text,
        }
      end
    )
  end

  def new_item(url = '', id = '')
    item = Constants::SMARTLING_ITEM.dup

    item.merge({
      Constants::KEYS[:id] => id,
      Constants::KEYS[:url] => url.gsub(/\/$/, ''),
      Constants::KEYS[:type] => Util.get_post_type(url),
    })
  end
end
