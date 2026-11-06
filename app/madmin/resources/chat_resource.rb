class ChatResource < Madmin::Resource
  attribute :id, form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false
  attribute :title
  attribute :support
  attribute :ticket_context
  attribute :pending_photos, index: false

  attribute :messages
  attribute :user
end
