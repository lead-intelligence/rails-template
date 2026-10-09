class Message < ApplicationRecord
  acts_as_message
  has_many_attached :attachments

  scope :visible_to_person, -> {
    where(chat: Chat.where(support: false))
      .or(where.not(role: %w[system tool]).where.not(id: ToolCall.select(:message_id)))
  }

  after_create_commit :broadcast_new_message
  after_update_commit :broadcast_updated_message
  after_destroy_commit :broadcast_removed_message

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

  def broadcast_new_message
    broadcast_append_to "chat_#{chat_id}", target: "chat_#{chat_id}_messages"
  end

  def broadcast_updated_message
    broadcast_append_to "chat_#{chat_id}", target: "chat_#{chat_id}_messages"
  end

  def broadcast_removed_message
    broadcast_remove_to "chat_#{chat_id}"
  end

  def hidden_from_person?
    role.to_s == "system" || role.to_s == "tool" || to_llm.tool_call?
  end
end
