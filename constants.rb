module Constants
  CATEGORY_TAG = {
    domain: 'category',
    name: 'Zendesk Nation',
    nicename: 'zendesk-nation'
  }

  CONTENT_TYPE_SUFFIXES = {
    'image/jpeg' => 'jpg',
    'image/png' => 'png'
  }

  KEYS = {
    id: 'item_id',
    image: 'item_thumbnail_url',
    url: 'item_url'
  }

  MIGRATED_IMAGES_DIR = 'https://d26a57ydsghvgx.cloudfront.net/content/migrated/'

  MAX_POSTS_PER_IMPORT_FILE = 60

  TAG_DOMAINS = ['filter_tag_blog', 'post_tag']

  UBERFLIP_CDN = /\Ahttps:\/\/content\.cdntwrk\.com/
end
