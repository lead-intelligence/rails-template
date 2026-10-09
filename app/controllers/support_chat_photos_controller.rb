class SupportChatPhotosController < ApplicationController
  before_action :set_chat
  before_action :ensure_open

  def create
    @chat.pending_photos.attach(photo_params)

    if @chat.errors[:pending_photos].any?
      error = upload_error
      @chat.reload
      render partial: "support_chats/photos", locals: { chat: @chat, error: error }, status: :unprocessable_entity
    else
      render partial: "support_chats/photos", locals: { chat: @chat, error: nil }
    end
  end

  private

  def set_chat
    @chat = Current.user.chats.support.find(params[:support_chat_id])
  end

  def ensure_open
    head :forbidden if @chat.closed?
  end

  def upload_error
    if @chat.errors.of_kind?(:pending_photos, :limit_max_exceeded)
      t("support_chat_photos.create.too_many", count: Chat::MAX_PENDING_PHOTOS)
    else
      t("support_chat_photos.create.upload_error")
    end
  end

  def photo_params
    params.expect(chat: [ pending_photos: [] ])[:pending_photos]
  end
end
