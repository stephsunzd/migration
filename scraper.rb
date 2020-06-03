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
      when 'post'
        postmeta[:title] = post.css('.hero-text h1')
        postmeta[:content] = post.css('.the-content .col-default')
        postmeta[:image] = post.css('.featured-image img').first.attribute('src').value
        postmeta[:tags] = post.css('.post-tag') && post.css('.hero .breadcrumbs a') && post.css('.hero .post-type')

        item['item_seo_description'] = item['item_description']
        item['author_first_name'] = post.css('.author').first.text unless post.css('.author').empty?
        item['author-title'] = post.css('.author.author-title').first.text unless post.css('.author.author-title').empty?
        item['author-twitter'] = post.css('.author a').first.text.gsub('@', '') unless post.css('.author a').empty?

        item['item_published_at'] = Util.cpubdate_to_timestamp(
          post.css('.hero-post-details .date').first.text
        ) unless post.css('.hero-post-details .date').empty?

        item['blog-post-gated-enable'] = post.css('.gated-content-cta').empty? ? 0 : 1

        if item['blog-post-gated-enable'].eql?(1)
          item['blog-post-gated-img'] = post.css('.gated-content-cta img').attribute('src')
          item['blog-post-gated-headline'] = post.css('.gated-content-cta h2').first.inner_html unless post.css('.gated-content-cta h2').empty?
          item['blog-post-gated-subheadline'] = post.css('.gated-content-cta p').first.inner_html unless post.css('.gated-content-cta p').empty?

          blog_gated_cta = post.css('.gated-content-cta .button-primary-default')

          unless blog_gated_cta.empty?
            item['blog-post-gated-url'] = blog_gated_cta.first.attribute('href').value
            item['blog-post-gated-button-text'] = blog_gated_cta.first.text
          end
        end
      when 'customer_lp'
        # These selectors are for LEGACY customer stories - you will need to update if your source is new customer stories
        postmeta[:excerpt] = post.css('.hero h1')
        postmeta[:content] = post.css('.customer-story-content-col')
        postmeta[:image] = post.css('.hero-main-image')

        item['item_title'] = item[Constants::KEYS[:url]].split('/').last.gsub('-', ' ')
        item['item_tags'] = get_product_tags(post.css('.product-col span'))
        item['logo'] = post.css('.customer-logos-container img').first.attribute('src').value
        item['item_seo_description'] = item['item_description']

        item[Constants::KEYS[:stats]] = get_stats(post.css('.customer-stats-row .col'))
      when 'webinar'
        postmeta[:title] = post.css('.p-webinar h1')
        postmeta[:image] = post.css('img.ico')

        item['item_seo_description'] = item['item_description']
        item['item_tags'] = [ Constants::WEBINAR_PUBLISH_TAG ]

        item[Constants::KEYS[:success]] = post.css('.success-message p').first.inner_html unless post.css('#event_id').empty?

        sidebar = post.css('.bio')
        unless sidebar.empty?
          item[Constants::KEYS[:author_bio]] = sidebar.first.inner_html
        end

        item['post_content'] = post.css('.p-webinar .col-small-5').first.inner_html
        item['post_content'] = item['post_content'].gsub(/<h3 class="h4">.*?<\/h3>/, '')

        item[Constants::KEYS[:webinar_dates]] = post.css('.p-webinar-hero--text p.h6').first.text
        item[Constants::KEYS[:webinar_presenters]] = get_webinar_presenters(post.css('.webinar-presenter-col'))
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

        item['post_excerpt'] = Util.excerpt(postmeta[:content].text) if item['post_excerpt'].empty?
      end

      unless postmeta[:image].empty?
        item[Constants::KEYS[:image]] = if !postmeta[:image].first.attribute('data-cfsrc').nil?
          postmeta[:image].first.attribute('data-cfsrc').value
        elsif postmeta[:image].first.attribute('src').nil?
          style_url_matches = postmeta[:image].first.attribute('style').value.scan(/url\((.+?)\)/)

          if style_url_matches.empty? || style_url_matches.first.empty?
            ""
          else
            style_url_matches.first.first
          end
        else
          postmeta[:image].first.attribute('src').value
        end
      end

      item['item_tags'] = postmeta[:tags].map do |tag|
        Constants::TAG_DOMAINS[item[Constants::KEYS[:type]]].map do |domain|
          {
            domain: domain,
            name: tag.text,
            nicename: tag.attribute('href').value[Constants::TAG_SLUG_RANGES[item[Constants::KEYS[:type]]]]
          }
        end
      end.flatten if item['item_tags'].empty?
    end # end if post.respond_to?(:css)

    item['pubDate'] = Util.timestamp_to_pubDate(item['item_published_at']) unless item['item_published_at'].nil?

    puts "# Scraped #{item[Constants::KEYS[:url]]}"

    return item
  end

  def get_product_tags(nodes)
    nodes.map do |node|
      tag_nicename = node.attribute('class').value.gsub('-icon-horizontal', '')
      tag_name = tag_nicename.split('-').last

      {
        domain: Constants::TAG_DOMAINS['customer_lp'].first,
        name: tag_name,
        nicename: tag_nicename
      }
    end
  end

  def get_stats(nodes)
    Util.serialize(
      nodes.map do |node|
        value = node.children.search('h2.customer-stat-value')
        title = node.children.search('p')

        {
          'customer-stat-title' => title.first.text,
          'customer-stat-value' => value.first.text,
        }
      end
    )
  end

  def get_webinar_presenters(nodes)
    Util.serialize(
      nodes.map do |node|
        {
          'presenter-name' => node.children.search('.webinar-presenter--name').first.text,
          'presenter-photo' => node.children.search('.webinar-presenter--photo').first.attribute('src').value,
          'presenter-title' => node.children.search('.webinar-presenter--title').first.text,
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
