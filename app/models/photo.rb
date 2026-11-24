module Photo
  CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  MAX_SIZE = 5.megabytes
  VALIDATION = { content_type: { in: CONTENT_TYPES, spoofing_protection: true }, size: { less_than: MAX_SIZE } }.freeze

  def self.formats
    CONTENT_TYPES.map { |type| type.delete_prefix("image/").upcase }.join(", ")
  end

  def self.max_size_in_words
    ActiveSupport::NumberHelper.number_to_human_size(MAX_SIZE)
  end
end
