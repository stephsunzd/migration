require_relative '../migration'

RSpec.describe "Migration" do
  TEST_CODES = { language: 'zd', country: 'zd' }
  TEST_URL = 'https://resources.zendesk.co.uk'
  TEST_ITEM = {
    'item_title' => 'Lorem ipsum',
    'author_first_name' => nil,
    'author_last_name' => nil,
    'item_canonical_url' => 'https://www.zendesk.com/blog/10-customer-experience-kpis/',
    'item_description' => 'Lorem ipsum dolor amet plaid slow-carb prism venmo kale chips. Lo-fi poke truffaut bushwick plaid. XOXO pug waistcoat edison bulb semiotics everyday carry succulents tbh hoodie literally mumblecore selvage. Intelligentsia tumblr gentrify, butcher venmo drinking vinegar readymade man bun ethical stumptown umami hoodie bespoke portland ennui. Aesthetic gastropub bitters pug unicorn pok pok.',
    'item_id' => '888888888',
    'item_published_at' => '2018-04-12 11:37:00',
    'item_seo_description' => 'Lorem SEO ipsum description.',
    'item_seo_title' => 'Lorem SEO ipsum',
    'item_tags' => [
      { name: 'Agent experience', domain: Migration::TAG_DOMAIN, nicename: 'agent-experience' },
      { name: 'Best Practices', domain: Migration::TAG_DOMAIN, nicename: 'best-practices' },
      { name: 'Customer experience', domain: Migration::TAG_DOMAIN, nicename: 'customer-experience' }
    ],
    'item_thumbnail_url' => 'https://d26a57ydsghvgx.cloudfront.net/content/blog/customer_experience_KPIs.png',
    'item_url' => 'https://resources.zendesk.co.uk/blog/10-customer-experience-kpis',
    'post_status' => 'publish',
    'pubDate' => 'Thu, 12 Apr 2018 11:37:00 +0000'
  }

  it '#timestamp_to_pubDate converts timestamp format to pubDate format' do
    timestamp = '2019-01-08 21:22:48'
    pubDate = 'Tue, 08 Jan 2019 21:22:48 +0000'

    expect(Migration.timestamp_to_pubDate(timestamp)).to eq(pubDate)
  end

  it '#generate_import_file creates a file matching our sample' do
    item = Migration.csv_to_item(TEST_CODES[:language])

    expect(item).to eq([TEST_ITEM])
  end

  it '#generate_import_file creates a file matching our sample' do
    Migration.generate_import_files(TEST_CODES, TEST_URL)

    posts_sample = File.open('spec/fixtures/posts_sample.xml').read.gsub(/( |\t)/, '')
    posts_zd = File.open('import_files/posts_zd_1.xml').read.gsub(/( |\t)/, '')

    expect(posts_sample).to eq(posts_zd)

    File.delete('import_files/posts_zd_1.xml')
  end
end
