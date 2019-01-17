require_relative '../util'

RSpec.describe "Util" do
  it '#timestamp_to_pubDate converts timestamp format to pubDate format' do
    timestamp = '2019-01-08 21:22:48'
    pubDate = 'Tue, 08 Jan 2019 21:22:48 +0000'

    expect(Util.timestamp_to_pubDate(timestamp)).to eq(pubDate)
  end
end
