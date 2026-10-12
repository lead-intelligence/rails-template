require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper
  include MessageQuotaHelper

  test "requires authentication" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    post chat_messages_url(chat), params: { message: { content: "Hi" } }
    assert_redirected_to new_session_url
  end

  test "enqueues a response and redirects for html requests" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")

    assert_enqueued_with(job: ChatResponseJob, args: [ chat.id ]) do
      post chat_messages_url(chat), params: { message: { content: "How do I deploy with Kamal?" } }
    end

    assert_redirected_to chat
  end

  test "enqueues a response and renders a turbo stream" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")

    assert_enqueued_with(job: ChatResponseJob, args: [ chat.id ]) do
      post chat_messages_url(chat), params: { message: { content: "How do I deploy with Kamal?" } }, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "answers 422 when the content is over the limit" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")

    assert_no_difference("chat.messages.count") do
      post chat_messages_url(chat), params: { message: { content: "a" * (Message::CONTENT_MAX_LENGTH + 1) } }, as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_no_enqueued_jobs only: ChatResponseJob
  end

  test "does nothing when the content is blank" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")

    assert_no_enqueued_jobs(only: ChatResponseJob) do
      post chat_messages_url(chat), params: { message: { content: "" } }, as: :turbo_stream
    end

    assert_response :success
  end

  test "answers 400 when the content is not text" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")

    assert_no_enqueued_jobs(only: ChatResponseJob) do
      [ "Hi", { content: [ "Hi" ] }, { content: { text: "Hi" } } ].each do |message|
        post chat_messages_url(chat), params: { message: message }
        assert_response :bad_request
      end
    end
  end

  test "does not accept messages for another user's chat" do
    sign_in_as users(:one)
    other_chat = users(:two).chats.create!(model: "gpt-4o-mini")
    post chat_messages_url(other_chat), params: { message: { content: "Hi" } }
    assert_response :not_found
  end
  test "a closed conversation refuses new messages" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(support: true, closed_at: Time.current)

    assert_no_enqueued_jobs(only: ChatResponseJob) do
      post chat_messages_url(chat), params: { message: { content: "¿Hola?" } }
    end

    assert_response :forbidden
    assert_equal 0, chat.messages.count
  end

  test "rate limits a burst of messages" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")

    20.times do |i|
      post chat_messages_url(chat), params: { message: { content: "Message #{i}" } }, as: :turbo_stream
    end

    assert_no_enqueued_jobs(only: ChatResponseJob) do
      post chat_messages_url(chat), params: { message: { content: "One too many" } }, as: :turbo_stream
    end

    assert_response :too_many_requests
    assert_equal 20, chat.messages.count
  end

  test "refuses a message once the daily quota is exhausted" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    seed_messages(chat, User::DAILY_MESSAGE_LIMIT)

    assert_no_enqueued_jobs(only: ChatResponseJob) do
      post chat_messages_url(chat), params: { message: { content: "One more" } }
    end

    assert_response :forbidden
    assert_equal User::DAILY_MESSAGE_LIMIT, chat.messages.count
  end

  test "the last message within the quota leaves the composer exhausted" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    seed_messages(chat, User::DAILY_MESSAGE_LIMIT - 1)

    post chat_messages_url(chat), params: { message: { content: "The last one" } }, as: :turbo_stream

    assert_response :success
    assert_no_match "new_message", @response.body
    assert_match I18n.t("messages.composer.exhausted", count: User::DAILY_MESSAGE_LIMIT), @response.body
  end

  test "the turbo stream response targets only this chat's own composer" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")

    post chat_messages_url(chat), params: { message: { content: "Hi" } }, as: :turbo_stream

    assert_response :success
    assert_match "target=\"composer_#{chat.id}\"", @response.body
  end

  test "a support reply re-renders the composer without the daily message counter" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(support: true)

    post chat_messages_url(chat), params: { message: { content: "No puedo entrar" } }, as: :turbo_stream

    assert_response :success
    assert_match "new_message", @response.body
    assert_no_match I18n.t("messages.composer.remaining", count: User::DAILY_MESSAGE_LIMIT - 1), @response.body
  end
end
