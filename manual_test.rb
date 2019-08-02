require_relative 'scraper'

item = {
  Constants::KEYS[:id] => '201900001',
  'item_published_at' => '2019-02-04 12:00:00',
  Constants::KEYS[:url] => 'https://www.zendesk.es/resources/5-biggest-gaps-customer-service-midsize-companies',
  'post_status' => 'publish',
  Constants::KEYS[:type] => 'resource',
  'item_tags' => []
}

item = Scraper.scrape_post(item)

puts item.inspect
