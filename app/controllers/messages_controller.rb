class MessagesController < ApplicationController
  rate_limit to: 20, within: 1.minute, only: :create, by: -> { Current.user.id }, with: -> { head :too_many_requests }
  before_action :set_chat
  before_action :ensure_open, only: :create
  before_action :ensure_within_quota, only: :create

  def create
    content = params.expect(message: [ :content ])[:content]
    if content.present?
      @user_message = @chat.add_message(role: :user, content: content)
      ChatResponseJob.perform_later(@chat.id)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @chat }
      end
    end
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  private

  def ensure_open
    head :forbidden if @chat.closed?
  end

  def set_chat
    @chat = Current.user.chats.find(params[:chat_id])
  end
end
