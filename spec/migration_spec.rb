require_relative '../migration'

RSpec.describe "generate import file" do
  TEST_CODES = { language: 'zd', country: 'zd' }
  TEST_URL = 'http://localhost:1337'
  TEST_ITEMS = [
    {
      'item_title' => 'Lorem ipsum',
      'item_tags' => []
    }
  ]

  it 'creates a file matching our sample' do
    Migration.generate_import_file(TEST_CODES, TEST_URL, TEST_ITEMS)

    posts_sample = File.open('spec/fixtures/posts_sample.xml').read
    posts_zd = File.open('import_files/posts_zd.xml').read

    expect(posts_sample).to eq(posts_zd)
  end
end
