module Util
  module_function

  def timestamp_to_pubDate(timestamp)
    pubDate = {
      year: timestamp[0..3].to_i,
      month: timestamp[5..6].to_i,
      day: timestamp[8..9].to_i,
      time: timestamp[11..18]
    }

    pubDate[:date] = Date.new(pubDate[:year], pubDate[:month], pubDate[:day])

    return "#{pubDate[:date].strftime('%a, %d %b %Y')} #{pubDate[:time]} +0000"
  end
end
