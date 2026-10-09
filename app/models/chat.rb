class Chat < ApplicationRecord
  INACTIVITY_WINDOW = 12.hours

  acts_as_chat
  belongs_to :user
  has_many :feedbacks, dependent: :nullify

  has_many_attached :pending_photos
  validates :pending_photos, content_type: %w[image/png image/jpeg image/webp], size: { less_than: 5.megabytes }

  scope :support, -> { where(support: true) }
  scope :open, -> { where(closed_at: nil) }

  def self.close_inactive_support_conversations
    support.open.find_each { |chat| chat.close! if chat.inactive? }
  end

  def closed?
    closed_at.present?
  end

  def inactive?
    last_activity_at <= INACTIVITY_WINDOW.ago
  end

  def close!
    return if closed?

    update!(closed_at: Time.current)
  end

  private

  def last_activity_at
    messages.maximum(:created_at) || created_at
  end
end
