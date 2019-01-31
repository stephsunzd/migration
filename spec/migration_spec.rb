require_relative '../migration'

RSpec.describe "Migration" do
  TEST_CODES = { language: 'zd', country: 'zd' }
  TEST_URL = 'https://resources.zendesk.co.uk'
  TEST_ITEM = {
    'item_title' => 'Lorem ipsum',
    'author_first_name' => nil,
    'author_last_name' => nil,
    'item_description' => 'Lorem ipsum dolor amet plaid slow-carb prism venmo kale chips. Lo-fi poke truffaut bushwick plaid. XOXO pug waistcoat edison bulb semiotics everyday carry succulents tbh hoodie literally mumblecore selvage. Intelligentsia tumblr gentrify, butcher venmo drinking vinegar readymade man bun ethical stumptown umami hoodie bespoke portland ennui. Aesthetic gastropub bitters pug unicorn pok pok.',
    'item_hidden' => 'FALSE',
    Constants::KEYS[:id] => '888888888',
    'item_published_at' => '2018-04-12 11:37:00',
    'item_seo_description' => 'Lorem SEO ipsum description.',
    'item_seo_title' => 'Lorem SEO ipsum',
    'item_tags' => [
      { name: 'Agent experience', domain: Constants::TAG_DOMAINS[0], nicename: 'agent-experience' },
      { name: 'Agent experience', domain: Constants::TAG_DOMAINS[1], nicename: 'agent-experience' },
      { name: 'Best Practices', domain: Constants::TAG_DOMAINS[0], nicename: 'best-practices' },
      { name: 'Best Practices', domain: Constants::TAG_DOMAINS[1], nicename: 'best-practices' },
      { name: 'Customer experience', domain: Constants::TAG_DOMAINS[0], nicename: 'customer-experience' },
      { name: 'Customer experience', domain: Constants::TAG_DOMAINS[1], nicename: 'customer-experience' }
    ],
    Constants::KEYS[:image] => 'https://d26a57ydsghvgx.cloudfront.net/content/migration/zd/zd-post-888888888.jpg',
    Constants::KEYS[:url] => 'https://resources.zendesk.co.uk/blog/10-customer-experience-kpis',
    'post_excerpt' => 'Lorem ipsum dolor amet plaid slow-carb prism venmo kale chips. Lo-fi poke truffaut bushwick plaid.',
    'post_status' => 'publish',
    Constants::KEYS[:type] => 'post',
    'pubDate' => 'Thu, 12 Apr 2018 11:37:00 +0000',
    'source_stream_title' => nil
  }

  it '#scrape_post handles nil item_url' do
    item = {
      Constants::KEYS[:url] => nil
    }

    expect(Migration.scrape_post(item)).to eq(item)
  end

  it '#scrape_post handles 404' do
    item = {
      Constants::KEYS[:url] => 'https://resources.zendesk.co.uk/blog/notapage',
      'post_content' => ''
    }

    expect(Migration.scrape_post(item)).to eq(item)
  end

  it '#csv_to_items creates an item matching our sample' do
    items = Migration.csv_to_items(TEST_CODES[:language])

    expect(items.first).to eq(TEST_ITEM)
  end

  it '#generate_import_file creates a file matching our sample' do
    Migration.generate_import_files(TEST_CODES, TEST_URL)

    posts_sample = File.open('spec/fixtures/posts_sample.xml').read.gsub(/( |\t)/, '')
    posts_zd = File.open('import_files/posts_zd_1.xml').read.gsub(/( |\t)/, '')

    expect(posts_sample).to eq(posts_zd)

    File.delete('import_files/posts_zd_1.xml')
  end
end
