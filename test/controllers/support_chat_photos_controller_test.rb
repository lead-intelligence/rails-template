require "test_helper"

class SupportChatPhotosControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  test "requires authentication" do
    chat = users(:one).chats.create!(support: true)

    post support_chat_photos_url(chat), params: { chat: { pending_photos: [ photo ] } }

    assert_redirected_to new_session_url
  end

  test "attaches an uploaded photo to the conversation" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(support: true)

    post support_chat_photos_url(chat), params: { chat: { pending_photos: [ photo ] } }

    assert_response :success
    assert chat.reload.pending_photos.attached?
  end

  test "never attaches the upload to another person's conversation" do
    sign_in_as users(:one)
    other_chat = users(:two).chats.create!(support: true)

    post support_chat_photos_url(other_chat), params: { chat: { pending_photos: [ photo ] } }

    assert_response :not_found
    assert_not other_chat.reload.pending_photos.attached?
  end

  test "never attaches the upload to an ordinary chat" do
    sign_in_as users(:one)
    ordinary = users(:one).chats.create!(support: false)

    post support_chat_photos_url(ordinary), params: { chat: { pending_photos: [ photo ] } }

    assert_response :not_found
    assert_not ordinary.reload.pending_photos.attached?
  end

  test "rejects an invalid photo with a human-friendly error and attaches nothing" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(support: true)

    post support_chat_photos_url(chat), params: { chat: { pending_photos: [ fixture_file_upload("note.txt", "text/plain") ] } }

    assert_response :unprocessable_entity
    assert_not chat.reload.pending_photos.attached?
    assert_includes @response.body, I18n.t("support_chat_photos.create.upload_error")
  end

  test "refuses photos for a closed conversation" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(support: true, closed_at: Time.current)

    post support_chat_photos_url(chat), params: { chat: { pending_photos: [ photo ] } }

    assert_response :forbidden
    assert_not chat.reload.pending_photos.attached?
  end

  test "refuses photos beyond the most a conversation holds and says how many fit" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(support: true)
    post support_chat_photos_url(chat), params: { chat: { pending_photos: Array.new(Chat::MAX_PENDING_PHOTOS) { photo } } }

    post support_chat_photos_url(chat), params: { chat: { pending_photos: [ photo ] } }

    assert_response :unprocessable_entity
    assert_equal Chat::MAX_PENDING_PHOTOS, chat.reload.pending_photos.count
    assert_includes @response.body, I18n.t("support_chat_photos.create.too_many", count: Chat::MAX_PENDING_PHOTOS)
  end

  private

  def photo
    fixture_file_upload("avatar.png", "image/png")
  end
end
