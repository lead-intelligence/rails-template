class UserResource < Madmin::Resource
  attribute :id, form: false
  attribute :email_address
  attribute :created_at, form: false
  attribute :updated_at, form: false
  attribute :name
  attribute :password, index: false, show: false
  attribute :password_confirmation, index: false, show: false
  attribute :avatar, index: false

  attribute :sessions
  attribute :chats
  attribute :documents
  attribute :feedbacks
  attribute :notifications
end
