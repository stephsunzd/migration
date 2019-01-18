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

  def excerpt(text, sentences = 2)
    return '' unless text.respond_to?(:split)

    text = text.split(/(?=[?.!])/)
    end_index = text.length < sentences ? -1 : sentences - 1

    ("#{text[0..end_index].join}.").gsub(/\A\s*/, '')
  end
end
