class Ahoy::Visit < ApplicationRecord
  RETENTION = 90.days

  self.table_name = "ahoy_visits"

  has_many :events, class_name: "Ahoy::Event", dependent: :destroy
  belongs_to :user, optional: true

  scope :expired, -> { where(started_at: ...RETENTION.ago) }

  def self.purge_expired
    Ahoy::Event.where(visit_id: expired.select(:id)).delete_all
    expired.delete_all
  end
end
