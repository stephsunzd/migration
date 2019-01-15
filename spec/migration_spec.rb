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
    'item_hidden' => 'FALSE',
    'item_id' => '888888888',
    'item_published_at' => '2018-04-12 11:37:00',
    'item_seo_description' => 'Lorem SEO ipsum description.',
    'item_seo_title' => 'Lorem SEO ipsum',
    'item_tags' => [
      { name: 'Agent experience' },
      { name: 'Best Practices' },
      { name: 'Customer experience' }
    ],
    'item_thumbnail_url' => 'https://d26a57ydsghvgx.cloudfront.net/content/blog/customer_experience_KPIs.png',
    'item_title' => 'Lorem ipsum',
    'item_url' => 'https://resources.zendesk.co.uk/blog/10-customer-experience-kpis'
  }

  it '#generate_import_file creates a file matching our sample' do
    item = Migration.csv_to_item(TEST_CODES[:language])

    expect(item).to eq([TEST_ITEM])
  end

  it '#generate_import_file creates a file matching our sample' do
    Migration.generate_import_file(TEST_CODES, TEST_URL)

    posts_sample = File.open('spec/fixtures/posts_sample.xml').read.gsub(' ', '')
    posts_zd = File.open('import_files/posts_zd.xml').read.gsub(' ', '')

    expect(posts_sample).to eq(posts_zd)

    File.delete('import_files/posts_zd.xml')
  end
end
