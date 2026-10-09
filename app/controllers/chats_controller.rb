class ChatsController < ApplicationController
  before_action :set_chat, only: [ :show, :destroy ]
  before_action :ensure_within_quota, only: :create

  def index
    @chats = Current.user.chats.where(support: false).includes(:model).left_joins(:messages).group(:id)
      .select("chats.*, COUNT(messages.id) AS messages_count").order(created_at: :desc)
  end

  def new
    @chat = Chat.new
    @selected_model = params[:model]
    @chat_models = available_chat_models
  end

  def create
    prompt = params.dig(:chat, :prompt)
    if prompt.present?
      @chat = Current.user.chats.create!(model: params.dig(:chat, :model).presence)
      @chat.create_user_message(prompt)
      ChatResponseJob.perform_later(@chat.id)

      redirect_to @chat, notice: t("chats.create.notice")
    end
  rescue RubyLLM::ModelNotFoundError
    @chat = Chat.new
    @chat.errors.add(:model, :unknown)
    @selected_model = params.dig(:chat, :model)
    @chat_models = available_chat_models
    render :new, status: :unprocessable_entity
  end

  def show
    @message = @chat.messages.build
    @messages = @chat.messages.where.not(id: nil).includes(:tool_calls, :parent_tool_call, :model, attachments_attachments: :blob)
  end

  def destroy
    @chat.destroy!
    redirect_to chats_path, notice: t("chats.destroy.notice"), status: :see_other
  end

  private

  def set_chat
    @chat = Current.user.chats.find(params[:id])
  end
end
