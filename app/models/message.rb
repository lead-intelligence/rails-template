class Message < ApplicationRecord
  CONTENT_MAX_LENGTH = 10_000

  acts_as_message

  validates :content, length: { maximum: CONTENT_MAX_LENGTH }, if: -> { role == "user" }

  scope :visible_to_person, -> {
    where(chat: Chat.where(support: false))
      .or(where.not(role: %w[system tool]).where.not(id: RubyLLM::ActiveRecord::ToolCall.where(message_type: name).select(:message_id)))
  }

  after_create :count_toward_daily_quota, if: -> { role.to_s == "user" }
  after_commit :broadcast_message, on: %i[ create update ]
  after_destroy_commit :broadcast_removed_message, unless: :destroyed_by_association

  def broadcast_append_chunk(content)
    broadcast_append_to "chat_#{chat_id}",
      target: "message_#{id}_content",
      content: ERB::Util.html_escape(content.to_s)
  end

  def broadcast_version
    updated_at.to_f
  end

  def to_partial_path
    return "messages/blank" if chat.support? && hidden_from_person?

    super
  end

  private

  def count_toward_daily_quota
    chat.user.count_sent_messages
  end

  def broadcast_message
    broadcast_append_to "chat_#{chat_id}", target: "chat_#{chat_id}_messages"
  end

  def broadcast_removed_message
    broadcast_remove_to "chat_#{chat_id}"
  end

  def hidden_from_person?
    role.to_s == "system" || role.to_s == "tool" || tool_call?
  end
end
