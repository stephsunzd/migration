require 'date'

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
        return excerpt_text
      end
    end

    excerpt_text
  end
end