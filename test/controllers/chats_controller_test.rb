require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper
  include MessageQuotaHelper
  include QueryCountHelper

  test "requires authentication" do
    get chats_url
    assert_redirected_to new_session_url
  end

  test "does not show another user's chat" do
    sign_in_as users(:one)
    other_chat = users(:two).chats.create!(model: "gpt-4o-mini")
    get chat_url(other_chat)
    assert_response :not_found
  end

  test "lists own chats" do
    sign_in_as users(:one)
    users(:one).chats.create!(model: "gpt-4o-mini")
    get chats_url
    assert_response :success
  end

  test "lists each chat with its message count" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    seed_messages(chat, 3)

    get chats_url

    assert_select "#chat_#{chat.id}", text: /#{I18n.t("chats.chat.messages")} 3/
  end

  test "the queries to list chats do not grow with the number of chats" do
    sign_in_as users(:one)
    seed_messages(users(:one).chats.create!(model: "gpt-4o-mini"), 2)
    one_chat = queries_to { get chats_url }

    4.times { seed_messages(users(:one).chats.create!(model: "gpt-4o-mini"), 2) }

    assert_equal one_chat, queries_to { get chats_url }
  end

  test "lists one page of own chats, newest first, and links to the next" do
    sign_in_as users(:one)
    chats = Array.new(ChatsController::PER_PAGE + 1) { |index| users(:one).chats.create!(model: "gpt-4o-mini", created_at: index.minutes.ago) }

    get chats_url

    assert_select "#chats > li.list-row", count: ChatsController::PER_PAGE
    assert_select "#chat_#{chats.first.id}"
    assert_select "#chat_#{chats.last.id}", count: 0
    assert_select "nav.pagy a[rel=next][href=?]", chats_path(page: 2)
  end

  test "lists the remaining own chats on the second page" do
    sign_in_as users(:one)
    chats = Array.new(ChatsController::PER_PAGE + 1) { |index| users(:one).chats.create!(model: "gpt-4o-mini", created_at: index.minutes.ago) }

    get chats_url(page: 2)

    assert_select "#chats > li.list-row", count: 1
    assert_select "#chat_#{chats.last.id}"
  end

  test "sends a page past the last one to the last page" do
    sign_in_as users(:one)
    Array.new(ChatsController::PER_PAGE + 1) { users(:one).chats.create!(model: "gpt-4o-mini") }

    get chats_url(page: "9" * 25)

    assert_redirected_to chats_url(page: 2)
  end

  test "the queries to show a chat do not grow with its tool results" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    add_tool_round(chat, 1)
    one_round = queries_to { get chat_url(chat) }

    2.upto(4) { |round| add_tool_round(chat, round) }

    assert_equal one_round, queries_to { get chat_url(chat) }
  end

  test "excludes support chats from the index" do
    sign_in_as users(:one)
    support_chat = users(:one).chats.create!(support: true)
    get chats_url
    assert_select "#chat_#{support_chat.id}", count: 0
  end

  test "shows a new chat form with the available models" do
    sign_in_as users(:one)
    get new_chat_url
    assert_response :success
    assert_select "select[name='chat[model]'] option", count: Chat.selectable_models.count + 1
    assert_select "option[value='gpt-4o-mini']"
    assert_select "option[value='text-embedding-3-small']", count: 0
  end

  test "shows an own chat" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    get chat_url(chat)
    assert_response :success
  end

  test "shows a chat with multiple messages without an N+1" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    chat.messages.create!(role: :user, content: "How do I deploy with Kamal?")
    chat.messages.create!(role: :assistant, content: "Run bin/kamal deploy.")

    get chat_url(chat)

    assert_response :success
  end

  test "creates a chat and enqueues the first response when a prompt is given" do
    sign_in_as users(:one)
    prompt = "How do I deploy with Kamal?"

    assert_difference("users(:one).chats.count", 1) do
      post chats_url, params: { chat: { model: "gpt-4o-mini", prompt: prompt } }
    end

    chat = Chat.last
    assert_equal [ [ "user", prompt ] ], chat.messages.pluck(:role, :content)
    assert_enqueued_with(job: ChatResponseJob, args: [ chat.id ])
    assert_redirected_to chat
  end

  test "answers 422 and keeps no chat when the prompt is over the limit" do
    sign_in_as users(:one)

    assert_no_difference("Chat.count") do
      post chats_url, params: { chat: { model: "gpt-4o-mini", prompt: "a" * (Message::CONTENT_MAX_LENGTH + 1) } }
    end

    assert_response :unprocessable_entity
    assert_no_enqueued_jobs only: ChatResponseJob
  end

  test "re-renders the form when the chosen model is unknown" do
    sign_in_as users(:one)

    assert_no_difference("Chat.count") do
      assert_no_enqueued_jobs(only: ChatResponseJob) do
        post chats_url, params: { chat: { model: "no-such-model", prompt: "Hola" } }
      end
    end

    assert_response :unprocessable_entity
    assert_select "#error_explanation", text: /#{I18n.t("activerecord.errors.models.chat.attributes.model.unknown")}/
  end

  test "refuses a model the registry knows but the form does not offer" do
    sign_in_as users(:one)
    other_provider_model = RubyLLM.models.chat_models.detect { |model| model.provider != Chat::PROVIDER.to_s }

    assert_no_difference("Chat.count") do
      post chats_url, params: { chat: { model: other_provider_model.id, prompt: "Hola" } }
    end

    assert_response :unprocessable_entity
    assert_select "#error_explanation", text: /#{I18n.t("activerecord.errors.models.chat.attributes.model.unknown")}/
  end

  test "creates a chat on the default model when none is chosen" do
    sign_in_as users(:one)

    post chats_url, params: { chat: { model: "", prompt: "Hola" } }

    assert_equal RubyLLM.config.default_model, Chat.last.model.model_id
  end

  test "does not create a chat when the prompt is blank" do
    sign_in_as users(:one)
    assert_no_difference("users(:one).chats.count") do
      assert_no_enqueued_jobs(only: ChatResponseJob) do
        post chats_url, params: { chat: { model: "gpt-4o-mini", prompt: "" } }
      end
    end
    assert_response :no_content
  end

  test "answers 400 when the prompt is not text" do
    sign_in_as users(:one)
    assert_no_difference("users(:one).chats.count") do
      [ "Hola", { prompt: [ "Hola" ] }, { prompt: { text: "Hola" } } ].each do |chat|
        post chats_url, params: { chat: chat }
        assert_response :bad_request
      end
    end
  end

  test "destroys an own chat" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    assert_difference("users(:one).chats.count", -1) do
      delete chat_url(chat)
    end
    assert_redirected_to chats_url
  end

  test "hides the composer once the daily quota is exhausted" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    seed_messages(users(:one).chats.create!(model: "gpt-4o-mini"), User::DAILY_MESSAGE_LIMIT)

    get chat_url(chat)

    assert_response :success
    assert_no_match "new_message", @response.body
    assert_match I18n.t("messages.composer.exhausted", count: User::DAILY_MESSAGE_LIMIT), @response.body
  end

  test "shows how many messages are left today on a fresh chat" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")

    get chat_url(chat)

    assert_response :success
    assert_match I18n.t("messages.composer.remaining", count: User::DAILY_MESSAGE_LIMIT), @response.body
  end

  test "refuses a new chat once the daily quota is exhausted" do
    sign_in_as users(:one)
    seed_messages(users(:one).chats.create!(model: "gpt-4o-mini"), User::DAILY_MESSAGE_LIMIT)

    assert_no_difference("users(:one).chats.count") do
      assert_no_enqueued_jobs(only: ChatResponseJob) do
        post chats_url, params: { chat: { model: "gpt-4o-mini", prompt: "One more" } }
      end
    end

    assert_response :forbidden
  end

  test "the new chat form gives way to the exhausted notice" do
    sign_in_as users(:one)
    seed_messages(users(:one).chats.create!(model: "gpt-4o-mini"), User::DAILY_MESSAGE_LIMIT)

    get new_chat_url

    assert_response :success
    assert_no_match I18n.t("chats.form.submit"), @response.body
    assert_match I18n.t("messages.composer.exhausted", count: User::DAILY_MESSAGE_LIMIT), @response.body
  end

  private

  def add_tool_round(chat, round)
    call = chat.messages.create!(role: :assistant, content: "").ruby_llm_tool_calls.create!(tool_call_id: "call_#{round}", name: "lookup", arguments: {})
    call.update!(result: chat.messages.create!(role: :tool, content: "Found #{round}"))
  end
end
