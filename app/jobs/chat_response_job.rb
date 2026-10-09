class ChatResponseJob < ApplicationJob
  limits_concurrency to: 1, key: ->(chat_id) { chat_id }, duration: 15.minutes

  def perform(chat_id)
    support = Chat.where(id: chat_id).pick(:support)
    chat = support ? SupportAgent.find(chat_id) : Chat.find(chat_id)

    begin
      chat.complete do |chunk|
        if chunk.content && !chunk.content.empty?
          message = chat.messages.last
          message.broadcast_append_chunk(chunk.content)
        end
      end
    rescue RubyLLM::Error
      broadcast_failure(chat)
      raise
    end

    GenerateChatTitleJob.perform_later(chat) unless chat.support?
  end

  private

  def broadcast_failure(chat)
    Turbo::StreamsChannel.broadcast_append_to "chat_#{chat.id}",
      target: "chat_#{chat.id}_messages",
      partial: "messages/failure",
      locals: { chat_id: chat.id }
  end
end
