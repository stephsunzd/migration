require_relative '../migration'

RSpec.describe "Migration" do
  TEST_CODES = { language: 'zd', country: 'zd' }
  TEST_URL = 'http://localhost:1337'
  TEST_ITEMS = [
    {
      'item_title' => 'Lorem ipsum',
      'item_tags' => []
    }
  ]

  it '#generate_import_file creates a file matching our sample' do
    Migration.generate_import_file(TEST_CODES, TEST_URL, TEST_ITEMS)

    posts_sample = File.open('spec/fixtures/posts_sample.xml').read.gsub(/\s/, '')
    posts_zd = File.open('import_files/posts_zd.xml').read.gsub(/\s/, '')

    expect(posts_sample).to eq(posts_zd)

    File.delete('import_files/posts_zd.xml')
  end
end
