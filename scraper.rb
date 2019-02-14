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
      when 'resource'
        postmeta[:title] = post.css('.blog-header h1')
        postmeta[:content] = post.css('.resource-body-teaser')
        postmeta[:image] = post.css('#main-image')
        postmeta[:tags] = post.css('.blog-tag')

        item['item_published_at'] = Util.cpubdate_to_timestamp(
          post.css('article.resource').first.attribute('cpubdate').value
        ) unless post.css('article.resource').empty? || post.css('article.resource').first.attribute('cpubdate').nil?
        item['resource-gated'] = post.css('.ungated').empty? ? 1 : 0

        item['resource-type'] = Constants::RESOURCE_TYPES[get_resource_type(post)]

        item['event-id'] = post.css('#event_id').first.attribute('value').value unless post.css('#event_id').empty?
        item['event-key'] = post.css('#event_key').first.attribute('value').value unless post.css('#event_key').empty?
        item['resource-video-url'] = post.css('section.video iframe').first.attribute('src').value unless post.css('section.video iframe').empty?
        item['resource-sidebar-quote'] = post.css('.twitter-pull-quote').first.text unless post.css('.twitter-pull-quote').empty?
        item['resource-download'] = post.css('.btn-submit').first.attribute('href').value unless post.css('.btn-submit').empty? || post.css('.btn-submit').first.attribute('href').nil?
        item['infographic'] = post.css('#infographic img').first.attribute('src').value unless post.css('#infographic img').empty?

        if !post.css('.gated-content-section-pager-wrapper').empty? &&
          !post.css('.gated-content-section-pager-wrapper').first.next.nil?
            node = post.css('.gated-content-section-pager-wrapper').first
            item['resource-body-copy'] = ''

            while node.next
              item['resource-body-copy'] += node.next.inner_html
              node = node.next
            end

            item['resource-body-copy'] = item['resource-body-copy'].gsub(Constants::SMARTLING_RESOURCE_BODY_REGEX, '')
        elsif !post.css('.resource-body-content').empty?
          puts 'resource body content found'
          item['resource-body-copy'] = post.css('.resource-body-content').first.inner_html
        end
      when 'webinar'
        postmeta[:title] = post.css('.post h1')
        postmeta[:content] = post.css('#reg p')
        postmeta[:image] = post.css('.post aside img')

        item['item_tags'] = [ Constants::WEBINAR_PUBLISH_TAG ]


        item[Constants::KEYS[:success]] = post.css('.success-message p').first.inner_html unless post.css('#event_id').empty?

        sidebar = post.css('.bio')
        unless sidebar.empty?
          item[Constants::KEYS[:author_bio]] = sidebar.first.inner_html
        end

        date_and_presenter = post.css('.post h2')
        unless date_and_presenter.empty?
          date_and_presenter = date_and_presenter.first.text.split(/,?\s(con|with|por)\s/i)
          item[Constants::KEYS[:webinar_dates]] = date_and_presenter.first
          item[Constants::KEYS[:author]] = date_and_presenter.last
        end
      end

      item[Constants::KEYS[:event_id]] = post.css('#event_id').first.attribute('value').value unless post.css('#event_id').empty?
      item[Constants::KEYS[:event_key]] = post.css('#event_key').first.attribute('value').value unless post.css('#event_key').empty?
      item[Constants::KEYS[:sf_cid]] = post.css('#SFDCCampaigncode').first.attribute('value').value unless post.css('#SFDCCampaigncode').empty?

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
            nicename: tag.attribute('href').value[Constants::TAG_SLUG_RANGES[item[Constants::KEYS[:type]]]]
          }
        end
      end.flatten if item['item_tags'].nil?
    end # end if post.respond_to?(:css)

    item['pubDate'] = Util.timestamp_to_pubDate(item['item_published_at']) unless item['item_published_at'].nil?

    puts "# Scraped #{item[Constants::KEYS[:url]]}"

    return item
  end

  def get_stats(nodes)
    Util.serialize(
      nodes.select do |node|
        node.children.search('img').empty?
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

  def get_resource_type(post)
    return unless post.respond_to?(:css)

    return :infographic unless post.css('#infographic').empty?

    unless post.css('#form-cta').empty?
      cta_text = post.css('#form-cta').first.text

      return :webinar if cta_text.match('webinar')
      return :guide if cta_text.match('guía')
      return :whitepaper if cta_text.match('técnico')
    end

    return :video unless post.css('.resource-body-video .video').empty?
    return :ebook if !post.css('.resource-body-teaser').empty? &&
      post.css('.resource-body-teaser').first.text.match(/e\-?book/i)

    :report
  end
end
