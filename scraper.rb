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
        postmeta[:title] = post.css('.blog-header h1')
        postmeta[:content] = post.css('.post-body')
        postmeta[:image] = post.css('.blog-image img')
        postmeta[:tags] = post.css('.blog-tag')

        item['item_seo_description'] = item['item_description']
        item['author_first_name'] = post.css('.post-author').first.text unless post.css('.post-author').empty?
        item['author-title'] = post.css('.post-author-title').first.text unless post.css('.post-author-title').empty?
        item['author-twitter'] = post.css('.post-twitter').first.text.gsub('@', '') unless post.css('.post-twitter').empty?

        item['item_published_at'] = Util.cpubdate_to_timestamp(
          post.css('article.post').first.attribute('cpubdate').value
        ) unless post.css('article.post').empty?

        item['blog-post-gated-enable'] = post.css('.gated-content-ad').empty? ? 0 : 1

        if item['blog-post-gated-enable'].eql?(1)
          item['blog-post-gated-img'] = post.css('.gated-content-image').first.attribute('style').value.scan(/url\('?"?(.+?)"?'?\)/).first.first unless post.css('.gated-content-image').empty?
          item['blog-post-gated-img'] = item['blog-post-gated-img'].gsub(/\s/, '')
          item['blog-post-gated-headline'] = post.css('.gated-content-text h4').first.inner_html unless post.css('.gated-content-text h4').empty?
          item['blog-post-gated-subheadline'] = post.css('.gated-content-teaser p').first.inner_html unless post.css('.gated-content-teaser p').empty?

          blog_gated_cta = post.css('.gated-content-ad .btn-primary-cta')

          unless blog_gated_cta.empty?
            item['blog-post-gated-url'] = blog_gated_cta.first.attribute('href').value
            item['blog-post-gated-button-text'] = blog_gated_cta.first.text
          end
        end
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
        postmeta[:title] = post.css('h1.h2')
        postmeta[:content] = post.css('.resource-teaser-copy')
        postmeta[:image] = post.css('.resource-media.show-small-up img')
        postmeta[:tags] = post.css('.post-tag')

        item['item_seo_description'] = item['item_description']
        item['item_published_at'] = Util.cpubdate_to_timestamp(
          post.css('article.resource').first.attribute('cpubdate').value
        ) unless post.css('article.resource').empty? || post.css('article.resource').first.attribute('cpubdate').nil?
        item['resource-gated'] = post.css('.ungated').empty? ? 1 : 0

        item['resource-type'] = Constants::RESOURCE_TYPES[get_resource_type(post)]

        item['event-id'] = post.css('#event_id').first.attribute('value').value unless post.css('#event_id').empty?
        item['event-key'] = post.css('#event_key').first.attribute('value').value unless post.css('#event_key').empty?
        item['resource-video-url'] = post.css('iframe').first.attribute('src').value unless post.css('section.video iframe').empty?
        puts "# First:  #{post.css('.resource-teaser-copy img').first.attribute('src').value unless post.css('.resource-teaser-copy img').empty?}"

        item['resource-sidebar-quote'] = post.css('.twitter-pull-quote').first.text unless post.css('.twitter-pull-quote').empty?
        item['resource-download'] = post.css('.success-message .button').first.attribute('href').value unless post.css('.success-message .button').empty? || post.css('.success-message .button').first.attribute('href').nil?
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
        postmeta[:title] = post.css('.p-webinar h1')
        postmeta[:image] = post.css('img.ico')

        item['item_seo_description'] = item['item_description']
        item['item_tags'] = [ Constants::WEBINAR_PUBLISH_TAG ]

        item[Constants::KEYS[:success]] = post.css('.success-message p').first.inner_html unless post.css('#event_id').empty?

        sidebar = post.css('.bio')
        unless sidebar.empty?
          item[Constants::KEYS[:author_bio]] = sidebar.first.inner_html
        end

        date_and_presenter_node = post.at_css('.p-webinar p.h6')
        unless date_and_presenter_node.nil?
          date_and_presenter = date_and_presenter_node.text.split(/,?\s(con|with|por)\s/i)
          item[Constants::KEYS[:webinar_dates]] = date_and_presenter.first
          item[Constants::KEYS[:author]] = date_and_presenter.last
          node = date_and_presenter_node

          item['post_content'] = post.css('.p-webinar .col-small-5').first.inner_html
          item['post_content'] = item['post_content'].gsub(/<h3 class="h4">.*?<\/h3>/, '')
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

    type = search_keyword_in(post, '.resource-lead-form-heading')

    if type.nil?
      type = search_keyword_in(post, '.p-single-resource, .single-resource')
    end

    type.nil? ? :report : type
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
