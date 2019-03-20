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
    author: 'author',
    author_bio: 'author_bio',
    id: 'item_id',
    image: 'item_thumbnail_url',
    sf_cid: 'sf_cid',
    event_id: 'event_id',
    event_key: 'event_key',
    stats: 'customer_stats',
    success: 'success_message',
    type: 'post_type',
    url: 'item_url',
    webinar_dates: 'webinar_dates',
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

  POST_TYPES = {
    'blog' => 'post',
    'resources' => 'resource',
    'support' => 'webinar',
    'customer' => 'customer_lp',
  }

  MAX_POSTS_PER_IMPORT_FILE = 60

  TAG_DOMAINS = {
    'post' => ['filter_tag_blog', 'post_tag'],
    'resource' => ['filter_tag'],
    'customer_lp' => ['stories_tax'],
    'webinar' => ['post_tag'],
  }

  TAG_SLUG_RANGES = {
    'post' => (11..-2),
    'resource' => (16..-2),
    'customer_lp' => (24..-1),
    'webinar' => (24..-1),
  }

  LIBRARY_VIDEO_TAGS = [
    { name: 'Videos', domain: 'filter_tag', nicename: 'library-videos' },
  ]

  WEBINAR_PUBLISH_TAG = {
    name: 'live',
    domain: 'post_tag',
    nicename: 'live',
  }

  SMARTLING_CONTENT_REGEX = /<section id="stats-box" class="cta">.*?<\/section>/m
  SMARTLING_RESOURCE_BODY_REGEX = /<a id="infographic" >.*?<\/a>/m

  SMARTLING_ITEM = {
    'item_published_at' => '2019-02-04 12:00:00',
    'item_tags' => [],
    'post_status' => 'publish',
  }

  SMARTLING_ID_START = 201900001

  UBERFLIP_CDN = /\Ahttps:\/\/content\.cdntwrk\.com/
  UBERFLIP_CDN_IMAGE_REGEXP = /https:\/\/content\.cdntwrk\.com\/files\/[\w%]+/
end
