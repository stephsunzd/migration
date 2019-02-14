require_relative 'scraper'

item = {
  Constants::KEYS[:id] => '201900001',
  'item_published_at' => '2019-02-04 12:00:00',
  Constants::KEYS[:url] => 'https://www.zendesk.com.mx/support/webinar/whats-new-product-updates-dec-2018-amer',
  'post_status' => 'publish',
  Constants::KEYS[:type] => 'webinar',
}

item = Scraper.scrape_post(item)

puts item.inspect
