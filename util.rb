require 'date'
require 'open-uri'
require 'csv'
require 'cgi'
require_relative 'constants'

module Util
  module_function

  def timestamp_to_pubDate(timestamp)
    pubDate = {
      year: timestamp[0..3].to_i,
      month: timestamp[5..6].to_i,
      day: timestamp[8..9].to_i,
      time: timestamp[11..-1]
    }

    pubDate[:date] = Date.new(pubDate[:year], pubDate[:month], pubDate[:day])

    return "#{pubDate[:date].strftime('%a, %d %b %Y')} #{pubDate[:time]} +0000"
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

  def post_type_empty?(row, col)
    col[Constants::KEYS[:type]].nil? ||
      row[col[Constants::KEYS[:type]]].nil? ||
      row[col[Constants::KEYS[:type]]].empty?
  end

  def download_image(url, subdir, new_filename = '')
    web_image = open(url)
    suffix = image_suffix(web_image)
    image_file_path = "images/#{subdir}/#{new_filename}.#{suffix}"

    IO.copy_stream(web_image, image_file_path)
  end

  def uberflip_image?(image_url)
    return false if image_url.nil?

    image_url.match(Constants::UBERFLIP_CDN)
  end

  def image_suffix(image)
    Constants::CONTENT_TYPE_SUFFIXES[image.content_type] || 'gif'
  end

  def clean_url(url)
    CGI.escape(url).gsub('%2F', '/').gsub('%3A', ':')
  end
end
