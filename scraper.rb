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
        postmeta[:image] = post.css('.featured-image img')
        postmeta[:tags] = post.css('.post-tag') && post.css('.hero .breadcrumbs a')

        item['item_seo_description'] = item['item_description']
        item['author_first_name'] = post.css('.author').first.text unless post.css('.author').empty?
        item['author-title'] = post.css('.author.author-title').first.text unless post.css('.author.author-title').empty?
        item['author-twitter'] = post.css('.author-twitter').first.text.gsub('@', '') unless post.css('.author-twitter').empty?

        item['item_published_at'] = Util.cpubdate_to_timestamp(
          post.css('.hero-post-details .date')
        ) unless post.css('.hero-post-details .date').empty?

        item['blog-post-gated-enable'] = post.css('.gated-content-cta').empty? ? 0 : 1

        if item['blog-post-gated-enable'].eql?(1)
          item['blog-post-gated-img'] = post.css('.gated-content-cta .relationframe').first.attribute('src').value.scan(/url\('?"?(.+?)"?'?\)/).first.first unless post.css('.gated-content-cta .relationframe').empty?
          item['blog-post-gated-img'] = item['blog-post-gated-img'].gsub(/\s/, '')
          item['blog-post-gated-headline'] = post.css('.gated-content-cta h2').first.inner_html unless post.css('.gated-content-cta h2').empty?
          item['blog-post-gated-subheadline'] = post.css('.gated-content-cta p').first.inner_html unless post.css('.gated-content-cta p').empty?

          blog_gated_cta = post.css('.gated-content-cta .button-primary-default')

          unless blog_gated_cta.empty?
            item['blog-post-gated-url'] = blog_gated_cta.first.attribute('href').value
            item['blog-post-gated-button-text'] = blog_gated_cta.first.text
          end
        end
      when 'customer_lp'
        postmeta[:title] = post.css('.hero h1')
        postmeta[:excerpt] = post.css('.hero p')
        postmeta[:content] = post.css('.customer-story-content-col')
        postmeta[:image] = post.css('.hero-main-image')
        postmeta[:tags] = post.css('.product-col span').first.attribute('src').value.split('-')[-1]

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

  def get_stats(nodes)
    Util.serialize(
      nodes.select do |node|
        node.children.search('span.stats-product-logo').empty?
      end.map do |node|
        spans = node.children.search('span')

        {
          'customer-stat-title' => spans.first.text,
          'customer-stat-value' => spans.last.text,
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

  def search_keyword_in(post, selector)
    unless post.css(selector).empty?
      search_text = post.css(selector).first.text

      return :ebook if search_text.match('eBook')
      return :whitepaper if search_text.match('técnico')
      return :webinar if search_text.match('webinar')
      return :video if search_text.match('video')
      return :guide if search_text.match('guía')
      return :infographic if search_text.match('infografía')
      return :report if search_text.match('el informe')
    end

    nil
  end
end
