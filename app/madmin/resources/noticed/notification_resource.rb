class Noticed::NotificationResource < Madmin::Resource
  attribute :id, form: false
  attribute :type
  attribute :read_at
  attribute :seen_at
  attribute :created_at, form: false
  attribute :updated_at, form: false

  attribute :event
  attribute :recipient
end
