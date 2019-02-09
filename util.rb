require 'date'
require 'open-uri'
require 'csv'
require 'cgi'
require_relative 'constants'

module Util
  module_function

  def cpubdate_to_timestamp(cpubdate)
    date = cpubdate.split(' ')
    date = Date.new(date[2].to_i, Date::MONTHNAMES.index(date[0]), date[1].to_i)

    "#{date.strftime('%Y-%m-%d')} 12:00:00"
  end

  def timestamp_to_pubDate(timestamp)
    pubDate = {
      year: timestamp[0..3].to_i,
      month: timestamp[5..6].to_i,
      day: timestamp[8..9].to_i,
      time: timestamp[11..-1]
    }

    pubDate[:date] = Date.new(pubDate[:year], pubDate[:month], pubDate[:day])

    "#{pubDate[:date].strftime('%a, %d %b %Y')} #{pubDate[:time]} +0000"
  end

  def excerpt(text, max_characters = 160)
    return '' unless text.respond_to?(:gsub, :split)

    # Clean partial sentences ending in ...
    text = text.gsub(/(\.|\?|!)\s+.*?\.\.\.\z/, '\1')

    # Convert line breaks to spaces (adding punctuation if missing)
    text = text.gsub(/(\w)\s*[\n\r]+\s*/, '\1. ')
    text = text.gsub(/\s{2,}/, ' ')
    text = text.gsub(/\A\s*/, '')

    text = text.split(/([?.!])/)
    excerpt_text = ''

    text.each do |sentence|
      next if sentence.empty?

      if excerpt_text.length + sentence.length < max_characters
        excerpt_text += sentence
      else
        return excerpt_text.empty? ? text.first : excerpt_text
      end
    end

    excerpt_text
  end

  def serialize(stats)
    serialized = "a:#{stats.size}:{"

    stats.each_with_index do |stat, index|
      serialized += "i:#{index};"
      serialized += "a:#{stat.size}:{"

      stat.each do |key, val|
        serialized += "s:#{serialize_count(key)}:\"#{key}\";"
        serialized += "s:#{serialize_count(val)}:\"#{val}\";"
      end

      serialized += "}"
    end

    serialized += "}"
  end

  def serialize_count(string)
    string.length +
      string.gsub(/[\w \.\+\/\$%\-]/, '').length
  end

  def download_images_from_csv(country_code, limit = nil)
    col = {}

    CSV.foreach("metadata_files/#{country_code}.csv").with_index do |row, index|
      if col.empty?
        row.each_with_index do |header, col_index|
          col[header] = col_index
        end

        return if col[Constants::KEYS[:image]].nil?

        next
      end

      # Allow force exit early for tests
      return if limit == index - 1

      # Ignore non-Uberflip images
      next unless uberflip_image?(row[col[Constants::KEYS[:image]]])

      post_type = post_type_empty?(row, col) ? 'post' : row[col[Constants::KEYS[:type]]]

      download_image(
        row[col[Constants::KEYS[:image]]],
        country_code,
        "#{country_code}-#{post_type}-#{row[col[Constants::KEYS[:id]]]}"
      )
    end # end CSV.foreach
  end

  def post_content_images(post_content, post_id, country_code)
    images = post_content.scan(Constants::UBERFLIP_CDN_IMAGE_REGEXP)

    images.each_with_index do |image, index|
      suffix = image_suffix(image)
      new_image_name = "#{country_code}-#{post_id}-#{index}"
      download_image(image, country_code, new_image_name)

      post_content.gsub!(image, "#{Constants::MIGRATED_IMAGES_DIR}#{country_code}/#{new_image_name}.#{suffix}")
    end

    post_content
  end

  def handle_resource(item)
    return item unless item[Constants::KEYS[:type]].eql?('resource')

    if item[Constants::KEYS[:url]].match(/\Ahttps:\/\/[\w\.]+\/self-service/)
      item['resource-type'] = Constants::RESOURCE_TYPES[:video]
      item['item_tags'] += Constants::LIBRARY_VIDEO_TAGS
    else
      item['resource-type'] = Constants::RESOURCE_TYPES[:whitepaper]
    end

    item
  end

  def get_post_type(url)
    slugs = url.scan(/\Ahttps?:\/\/[a-z\.\-]+\/(.+?)\//)

    return if slugs.empty?

    Constants::POST_TYPES[slugs.first.first]
  end

  def post_type_empty?(row, col)
    col[Constants::KEYS[:type]].nil? ||
      row[col[Constants::KEYS[:type]]].nil? ||
      row[col[Constants::KEYS[:type]]].empty?
  end

  def download_image(url, subdir, new_filename = '')
    suffix = image_suffix(url)
    return false if suffix.empty?

    begin
      puts "Downloading #{url}"
      web_image = open(url)
    rescue OpenURI::HTTPError => http_error
      puts http_error
      return false
    end

    image_file_path = "images/#{subdir}/#{new_filename}.#{suffix}"

    IO.copy_stream(web_image, image_file_path)
  end

  def uberflip_image?(image_url)
    return false if image_url.nil?

    image_url.match(Constants::UBERFLIP_CDN)
  end

  def image_suffix(image)
    begin
      web_image = open(image)
      return Constants::CONTENT_TYPE_SUFFIXES[web_image.content_type] || 'gif'
    rescue OpenURI::HTTPError => http_error
      puts http_error
    end

    ''
  end

  def clean_url(url)
    CGI.escape(url).gsub('%2F', '/').gsub('%3A', ':')
  end
end
