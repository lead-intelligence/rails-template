class Feedback < ApplicationRecord
  belongs_to :user
  belongs_to :chat, optional: true
  MESSAGE_MAX_LENGTH = 10_000
  HOURLY_LIMIT = 5

  has_many_attached :photos

  enum :status, { open: "open", resolved: "resolved" }

  scope :within_the_last_hour, -> { where(created_at: 1.hour.ago..) }

  validates :message, presence: true, length: { maximum: MESSAGE_MAX_LENGTH }
  validates :photos, content_type: { in: %w[image/png image/jpeg image/webp], spoofing_protection: true }, size: { less_than: 5.megabytes }

  after_create_commit :create_github_issue_later

  def resolve!
    return if resolved?

    update!(status: :resolved, resolved_at: Time.current)
    chat&.close!
  end

  private

  def create_github_issue_later
    CreateFeedbackIssueJob.perform_later(self)
  end
end
