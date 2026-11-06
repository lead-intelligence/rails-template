class SessionResource < Madmin::Resource
  attribute :id, form: false
  attribute :ip_address
  attribute :user_agent
  attribute :created_at, form: false
  attribute :updated_at, form: false

  attribute :user
end
