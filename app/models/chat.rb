class Chat < ApplicationRecord
  INACTIVITY_WINDOW = 12.hours
  MAX_PENDING_PHOTOS = 5

  acts_as_chat
  belongs_to :user
  has_many :feedbacks, dependent: :nullify

  has_many_attached :pending_photos
  validates :pending_photos, content_type: %w[image/png image/jpeg image/webp], size: { less_than: 5.megabytes },
    limit: { max: MAX_PENDING_PHOTOS }

  scope :support, -> { where(support: true) }
  scope :open, -> { where(closed_at: nil) }
  scope :with_first_question, -> {
    first_question = Message.where(role: "user").where("messages.chat_id = chats.id").order(:created_at).limit(1).select(:content)
    select(arel_table[Arel.star], first_question.arel.as("first_question"))
  }
  scope :inactive, -> {
    last_message_at = Message.where("messages.chat_id = chats.id").select(Message.arel_table[:created_at].maximum)
    last_activity_at = Arel::Nodes::NamedFunction.new("COALESCE", [ last_message_at.arel, arel_table[:created_at] ])
    where(last_activity_at.lteq(INACTIVITY_WINDOW.ago))
  }

  def self.close_inactive_support_conversations
    support.open.inactive.find_each(&:close!)
  end

  def as_json(options = nil) = serializable_hash(options)

  def closed?
    closed_at.present?
  end

  def close!
    return if closed?

    update!(closed_at: Time.current)
    discard_pending_photos
  end

  private

  def discard_pending_photos
    return unless pending_photos.attached?

    blob_ids = pending_photos.blobs.ids
    pending_photos.detach
    ActiveStorage::Blob.unattached.where(id: blob_ids).find_each(&:purge_later)
  end
end
