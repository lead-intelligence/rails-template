class Feedback < ApplicationRecord
  belongs_to :user
  belongs_to :chat, optional: true
  MESSAGE_MAX_LENGTH = 10_000

  has_many_attached :photos

  enum :status, { open: "open", resolved: "resolved" }

  validates :message, presence: true, length: { maximum: MESSAGE_MAX_LENGTH }
  validates :photos, content_type: %w[image/png image/jpeg image/webp], size: { less_than: 5.megabytes }

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
