class Session < ApplicationRecord
  INACTIVITY_LIMIT = 30.days

  belongs_to :user

  scope :inactive, -> { where(updated_at: ...INACTIVITY_LIMIT.ago) }

  def self.purge_inactive
    inactive.delete_all
  end

  def inactive?
    updated_at < INACTIVITY_LIMIT.ago
  end

  def record_activity
    touch if updated_at < 1.day.ago
  end
end
