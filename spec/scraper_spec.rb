require_relative '../scraper'
require_relative 'fixtures/content'

RSpec.describe "Scraper" do
  TEST_CODES_SCRAPER = { language: 'zd', country: 'zd' }
  TEST_URL_SCRAPER = 'https://www.zendesk.com.mx'
  TEST_ITEM_SCRAPER = {
    Constants::KEYS[:stats] => 'a:1:{i:0;a:2:{s:19:"customer-stat-title";s:0:"";s:19:"customer-stat-value";s:0:"";}}',
    'item_title' => 'Dollar Shave Club',
    'item_description' => 'Dollar Shave Club resuelve el 12 % de sus tickets con el Answer Bot de Zendesk',
    Constants::KEYS[:id] => '201900001',
    'item_published_at' => '2019-02-04 12:00:00',
    'item_seo_description' => 'Dollar Shave Club resuelve el 12 % de sus tickets con el Answer Bot de Zendesk',
    'item_tags' => [
      { name: 'América', domain: 'stories_tax', nicename: 'americas' },
      { name: 'Chat', domain: 'stories_tax', nicename: 'product-chat' },
      { name: 'Guide', domain: 'stories_tax', nicename: 'product-guide' },
      { name: 'Internet y móviles', domain: 'stories_tax', nicename: 'internet-mobile' },
      { name: 'Comercio minorista y electrónico', domain: 'stories_tax', nicename: 'retail' },
      { name: 'Support', domain: 'stories_tax', nicename: 'product-support' },
    ],
    Constants::KEYS[:image] => 'https://d26a57ydsghvgx.cloudfront.net/product/Customer%20Story%20Images/Dollarshave7.jpg',
    Constants::KEYS[:url] => 'https://www.zendesk.com.mx/customer/dollar-shave-club',
    'post_content' => TEST_CONTENT[:customer_lp],
    'post_excerpt' => 'Dollar Shave Club reduce el coste del servicio con Answer Bot',
    'post_status' => 'publish',
    Constants::KEYS[:type] => 'customer_lp',
    'pubDate' => 'Mon, 04 Feb 2019 12:00:00 +0000',
  }
  TEST_ITEM_STUB = {
    Constants::KEYS[:id] => '201900001',
    'item_published_at' => '2019-02-04 12:00:00',
    Constants::KEYS[:url] => 'https://www.zendesk.com.mx/customer/dollar-shave-club',
    'post_status' => 'publish',
    Constants::KEYS[:type] => 'customer_lp',
  }

  it '#new_item handles nil url' do
    nil_stub = {
      "item_published_at" => "2019-02-04 12:00:00",
      Constants::KEYS[:url] => "",
      Constants::KEYS[:type] => nil,
      'post_status' => 'publish',
    }

    expect(Scraper.new_item()).to eql(nil_stub)
  end

  it '#new_item creates a new item stub from url' do
    expect(Scraper.new_item(TEST_ITEM_STUB[Constants::KEYS[:url]])).to eql(TEST_ITEM_STUB)
  end

  it '#scrape_post handles nil item_url' do
    item = {
      Constants::KEYS[:url] => nil
    }

    expect(Scraper.scrape_post(item)).to eq(item)
  end

  it '#scrape_post handles 404' do
    item = {
      Constants::KEYS[:url] => 'https://www.zendesk.com.mx/customer/notapage',
    }

    expect(Scraper.scrape_post(item)).to eq(item)
  end

  it '#scrape_post returns item matching our sample' do
    expect(Scraper.scrape_post(TEST_ITEM_STUB)).to eq(TEST_ITEM_SCRAPER)
  end

  xit '#generate_import_file creates a file matching our sample' do
    Scraper.generate_import_files(TEST_CODES_SCRAPER, TEST_URL)

    posts_sample = File.open('spec/fixtures/posts_sample.xml').read.gsub(/( |\t)/, '')
    posts_zd = File.open('import_files/posts_zd_1.xml').read.gsub(/( |\t)/, '')

    expect(posts_sample).to eq(posts_zd)

    File.delete('import_files/posts_zd_1.xml')
  end
end
