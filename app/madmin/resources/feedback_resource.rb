class FeedbackResource < Madmin::Resource
  attribute :id, form: false
  attribute :message
  attribute :created_at, form: false
  attribute :updated_at, form: false
  attribute :context
  attribute :status
  attribute :resolved_at
  attribute :photos, index: false

  attribute :user
end
