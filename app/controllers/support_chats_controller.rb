class SupportChatsController < ApplicationController
  CONTEXT_KEYS = %i[page_url user_agent viewport].freeze
  CONTEXT_VALUE_LIMIT = 2.kilobytes
  RECENT_CONVERSATIONS = 5

  def index
    @context = context_params
    @chats = conversations.with_first_question.order(created_at: :desc).limit(RECENT_CONVERSATIONS)
  end

  def show
    @chat = conversations.find(params[:id])
    @message = @chat.messages.build
    @messages = @chat.messages.includes(:tool_calls, :parent_tool_call, :model, attachments_attachments: :blob).order(:created_at)
  end

  def create
    redirect_to support_chat_path(conversations.create!(ticket_context: context_params.presence))
  end

  private

  def conversations
    Current.user.chats.support
  end

  def context_params
    params.permit(context: CONTEXT_KEYS).to_h.fetch(:context, {}).transform_values { |value| sanitize_context_value(value) }
  end

  def sanitize_context_value(value)
    value.to_s.gsub(/[\r\n]+/, " ").byteslice(0, CONTEXT_VALUE_LIMIT).scrub("")
  end
end
