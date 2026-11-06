class Noticed::EventResource < Madmin::Resource
  attribute :id, form: false
  attribute :type
  attribute :params
  attribute :created_at, form: false
  attribute :updated_at, form: false
  attribute :notifications_count, form: false

  attribute :record
  attribute :notifications
end
