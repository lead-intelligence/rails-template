class MessageResource < Madmin::Resource
  attribute :id, form: false
  attribute :role
  attribute :content
  attribute :thinking_text
  attribute :thinking_signature
  attribute :thinking_tokens
  attribute :input_tokens
  attribute :output_tokens
  attribute :cached_tokens
  attribute :cache_creation_tokens
  attribute :created_at, form: false
  attribute :updated_at, form: false
  attribute :attachments, index: false

  attribute :chat
end
