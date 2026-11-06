class GenerateChatTitleJob < ApplicationJob
  queue_as :default

  def perform(chat)
    return if chat.title.present?
    first_question = chat.messages.where(role: "user").order(:created_at).first
    return if first_question.nil?
    response = RubyLLM.with_usage_owner(chat.user) do
      RubyLLM.chat.with_schema(ChatTitleSchema).ask("Title this conversation: #{first_question.content}")
    end
    chat.update!(title: response.parsed["title"])
  end
end
