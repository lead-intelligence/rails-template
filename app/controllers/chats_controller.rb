class ChatsController < ApplicationController
  PER_PAGE = 25

  before_action :set_chat, only: [ :show, :destroy ]
  before_action :ensure_within_quota, only: :create

  def index
    @pagy, @chats = pagy(listed_chats, limit: PER_PAGE)
  end

  def new
    @chat = Chat.new
    @selected_model = params[:model]
    @chat_models = selectable_chat_models
  end

  def create
    prompt = chat_params[:prompt]
    if prompt.present?
      @chat = Current.user.chats.create!(model: chosen_model)
      @chat.add_message(role: :user, content: prompt)
      ChatResponseJob.perform_later(@chat.id)

      redirect_to @chat, notice: t("chats.create.notice")
    end
  rescue RubyLLM::ModelNotFoundError
    @chat = Chat.new
    @chat.errors.add(:model, :unknown)
    @selected_model = chat_params[:model]
    @chat_models = selectable_chat_models
    render :new, status: :unprocessable_entity
  end

  def show
    @message = @chat.messages.build
    @messages = @chat.messages.where.not(id: nil).includes(:ruby_llm_tool_calls, :ruby_llm_parent_tool_call)
  end

  def destroy
    @chat.destroy!
    redirect_to chats_path, notice: t("chats.destroy.notice"), status: :see_other
  end

  private

  def listed_chats
    Current.user.chats.where(support: false).includes(:model).left_joins(:messages).group(:id)
      .select("chats.*, COUNT(messages.id) AS messages_count").order(created_at: :desc, id: :desc)
  end

  def set_chat
    @chat = Current.user.chats.find(params[:id])
  end

  def chat_params
    params.expect(chat: [ :prompt, :model ])
  end

  def chosen_model
    model = chat_params[:model].presence
    return unless model

    Chat.selectable_models.detect { |selectable| selectable.id == model }&.id or raise RubyLLM::ModelNotFoundError, model
  end

  def selectable_chat_models
    Chat.selectable_models.sort_by { |model| model.name.to_s }
  end
end
