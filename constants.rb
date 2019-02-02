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
    type: 'post_type',
    url: 'item_url'
  }

  RESOURCE_TYPES = {
    video: 1,
    webinar: 2,
    whitepaper: 3,
    guide: 5,
    report: 6,
    ebook: 7,
    infographic: 8,
  }

  MIGRATED_IMAGES_DIR = 'https://d26a57ydsghvgx.cloudfront.net/content/migration/'

  MAX_POSTS_PER_IMPORT_FILE = 60

  TAG_DOMAINS = ['filter_tag_blog', 'post_tag']

  LIBRARY_VIDEO_TAGS = [
    { name: 'Videos', domain: 'filter_tag', nicename: 'library-videos' },
  ]

  UBERFLIP_CDN = /\Ahttps:\/\/content\.cdntwrk\.com/
  UBERFLIP_CDN_IMAGE_REGEXP = /https:\/\/content\.cdntwrk\.com\/files\/[\w%]+/
end
