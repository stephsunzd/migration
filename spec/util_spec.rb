require_relative '../util'

RSpec.describe "Util" do
  it '#timestamp_to_pubDate converts timestamp format to pubDate format' do
    timestamp = '2019-01-08 21:22:48'
    pubDate = 'Tue, 08 Jan 2019 21:22:48 +0000'

    expect(Util.timestamp_to_pubDate(timestamp)).to eq(pubDate)
  end

  it '#excerpt handles nil text' do
    expect(Util.excerpt(nil)).to eq('')
  end

  it '#excerpt handles empty string' do
    expect(Util.excerpt('')).to eq('')
  end

  it '#excerpt trims cut-off sentences' do
    expect(Util.excerpt('Hello. World...')).to eq('Hello.')
  end

  it '#excerpt converts line breaks to spaces and adds period if none' do
    text = 'Feedback in business is crucial to growing and improving

It’s beneficial for any business to take a closer look at what is working.'
    text_excerpt = 'Feedback in business is crucial to growing and improving. It’s beneficial for any business to take a closer look at what is working.'

    expect(Util.excerpt(text)).to eq(text_excerpt)
  end

  it '#excerpt returns full sentences and max 160 characters of a longer text' do
    text = 'Feedback in business is crucial to growing and improving. It’s beneficial for any business to take a closer look at what is working and what could use improvement on a regular basis. But how do you do that? Where do you start? There are lots of ways to collect customer feedback—one of the most common tools is a customer survey. NPS®, Transactional CSAT, Global CSAT, and Customer Effort Scores are a few customer surveys you can use, but what should you ask your customers?'
    text_excerpt = 'Feedback in business is crucial to growing and improving.'

    expect(Util.excerpt(text)).to eq(text_excerpt)
  end
end
