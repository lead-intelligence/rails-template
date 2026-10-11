class ChatResponseJob < ApplicationJob
  STREAM_INTERVAL = 0.1

  limits_concurrency to: 1, key: ->(chat_id) { chat_id }, duration: 15.minutes
  discard_on ActiveRecord::RecordNotFound

  def perform(chat_id)
    support = Chat.where(id: chat_id).pick(:support)
    chat = support ? SupportAgent.find(chat_id) : Chat.find(chat_id)

    begin
      chat.complete do |chunk|
        stream(chat.messages.last, chunk.content) unless chunk.content.to_s.empty?
      end
    rescue RubyLLM::Error
      broadcast_failure(chat)
      raise
    end

    GenerateChatTitleJob.perform_later(chat) unless chat.support?
  end

  private

  def stream(message, content)
    @pending = +"" unless message == @streaming
    @streaming = message
    @pending << content

    time = now
    return if @streamed_at && time - @streamed_at < STREAM_INTERVAL

    message.broadcast_append_chunk(@pending)
    @pending = +""
    @streamed_at = time
  end

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def broadcast_failure(chat)
    Turbo::StreamsChannel.broadcast_append_to "chat_#{chat.id}",
      target: "chat_#{chat.id}_messages",
      partial: "messages/failure",
      locals: { chat_id: chat.id }
  end
end
