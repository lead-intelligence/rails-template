class DocumentResource < Madmin::Resource
  attribute :id, form: false
  attribute :title
  attribute :created_at, form: false
  attribute :updated_at, form: false
  attribute :embedding
  attribute :content, index: false

  attribute :user
end
