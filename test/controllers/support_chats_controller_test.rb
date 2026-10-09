require "test_helper"

class SupportChatsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper
  include MessageQuotaHelper

  test "the conversation list requires authentication" do
    get support_chats_url
    assert_redirected_to new_session_url
  end

  test "the list starts empty and creates nothing on its own" do
    sign_in_as users(:one)

    assert_no_difference("Chat.count") do
      get support_chats_url
    end

    assert_response :success
  end

  test "the list shows the person's own conversations, most recent first" do
    sign_in_as users(:one)
    older = users(:one).chats.create!(support: true, created_at: 2.days.ago)
    older.messages.create!(role: :user, content: "No puedo entrar")
    newer = users(:one).chats.create!(support: true, created_at: 1.hour.ago)
    newer.messages.create!(role: :user, content: "La factura sale mal")

    get support_chats_url

    assert_response :success
    assert_operator @response.body.index("La factura sale mal"), :<, @response.body.index("No puedo entrar")
  end

  test "the list names each conversation by its first question" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(support: true)
    chat.messages.create!(role: :user, content: "No puedo entrar", created_at: 3.minutes.ago)
    chat.messages.create!(role: :assistant, content: "Contame mas", created_at: 2.minutes.ago)
    chat.messages.create!(role: :user, content: "Me da error", created_at: 1.minute.ago)

    get support_chats_url

    assert_match "No puedo entrar", @response.body
    assert_no_match "Me da error", @response.body
  end

  test "the list loads no conversation's whole history" do
    sign_in_as users(:one)
    seed_messages(users(:one).chats.create!(support: true), 3)

    assert_no_queries_match(/\ASELECT "messages"/) { get support_chats_url }
  end

  test "the list leaves out other people's conversations" do
    sign_in_as users(:one)
    intruder = users(:two).chats.create!(support: true)
    intruder.messages.create!(role: :user, content: "Secreto ajeno")

    get support_chats_url

    assert_no_match "Secreto ajeno", @response.body
  end

  test "the list leaves out the person's ordinary chats" do
    sign_in_as users(:one)
    ordinary = users(:one).chats.create!(support: false)
    ordinary.messages.create!(role: :user, content: "Charla comun")

    get support_chats_url

    assert_no_match "Charla comun", @response.body
  end

  test "starting a conversation creates one and opens it" do
    sign_in_as users(:one)

    assert_difference("users(:one).chats.support.count", 1) do
      post support_chats_url
    end

    assert_redirected_to support_chat_url(users(:one).chats.support.sole)
  end

  test "each new conversation is separate from the previous ones" do
    sign_in_as users(:one)

    assert_difference("users(:one).chats.support.count", 2) do
      post support_chats_url
      post support_chats_url
    end
  end

  test "opening a conversation shows it" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(support: true)
    chat.messages.create!(role: :user, content: "Hola equipo")

    get support_chat_url(chat)

    assert_response :success
    assert_match "Hola equipo", @response.body
  end

  test "someone else's conversation is not reachable" do
    sign_in_as users(:one)
    intruder = users(:two).chats.create!(support: true)

    get support_chat_url(intruder)

    assert_response :not_found
  end

  test "an ordinary chat is not reachable through the support routes" do
    sign_in_as users(:one)
    ordinary = users(:one).chats.create!(support: false)

    get support_chat_url(ordinary)

    assert_response :not_found
  end

  test "does not render technical tool call details for the person" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(support: true)
    message = chat.messages.create!(role: :assistant, content: "")
    message.tool_calls.create!(tool_call_id: "call_1", name: "create_support_ticket", arguments: { title: "x", summary: "y" })

    get support_chat_url(chat)

    assert_response :success
    assert_no_match "create_support_ticket", @response.body
  end

  test "stores the page url, user agent and viewport sent when the conversation starts" do
    sign_in_as users(:one)

    post support_chats_url, params: { context: { page_url: "https://example.com/chats/1", user_agent: "TestBrowser/1.0", viewport: "1512x982" } }

    chat = users(:one).chats.support.sole
    assert_equal "https://example.com/chats/1", chat.ticket_context["page_url"]
    assert_equal "TestBrowser/1.0", chat.ticket_context["user_agent"]
    assert_equal "1512x982", chat.ticket_context["viewport"]
  end

  test "truncates context values to 2 kilobytes" do
    sign_in_as users(:one)

    post support_chats_url, params: { context: { page_url: "x" * 3000 } }

    assert_equal 2.kilobytes, users(:one).chats.support.sole.ticket_context["page_url"].length
  end

  test "truncates context values to 2 kilobytes of bytes, not characters" do
    sign_in_as users(:one)

    post support_chats_url, params: { context: { page_url: "€" * 3000 } }

    assert_operator users(:one).chats.support.sole.ticket_context["page_url"].bytesize, :<=, 2.kilobytes
  end

  test "strips newlines from context values so they cannot forge the issue metadata separator" do
    sign_in_as users(:one)

    post support_chats_url, params: { context: { page_url: "https://example.com\r\n---\r\nForged line" } }

    assert_equal "https://example.com --- Forged line", users(:one).chats.support.sole.ticket_context["page_url"]
  end

  test "strips lone carriage returns from context values too" do
    sign_in_as users(:one)

    post support_chats_url, params: { context: { page_url: "https://example.com\rInjected\r---\rmore" } }

    assert_equal "https://example.com Injected --- more", users(:one).chats.support.sole.ticket_context["page_url"]
  end

  test "ignores unknown context keys" do
    sign_in_as users(:one)

    post support_chats_url, params: { context: { page_url: "https://example.com", admin: "true" } }

    assert_not users(:one).chats.support.sole.ticket_context.key?("admin")
  end

  test "leaves the context empty when none is sent" do
    sign_in_as users(:one)

    post support_chats_url

    assert_nil users(:one).chats.support.sole.ticket_context
  end

  test "a closed conversation is shown without a way to keep writing" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(support: true, closed_at: Time.current)
    chat.messages.create!(role: :user, content: "Ya lo resolvimos")

    get support_chat_url(chat)

    assert_response :success
    assert_match "Ya lo resolvimos", @response.body
    assert_no_match "new_message", @response.body
    assert_match I18n.t("support_chats.show.closed"), @response.body
  end

  test "the widget shows the composer without the daily message counter" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(support: true)

    get support_chat_url(chat)

    assert_response :success
    assert_match "new_message", @response.body
    assert_no_match I18n.t("messages.composer.remaining", count: User::DAILY_MESSAGE_LIMIT), @response.body
  end

  test "the widget still hides the composer once the daily quota is exhausted" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!(support: true)
    seed_messages(chat, User::DAILY_MESSAGE_LIMIT)

    get support_chat_url(chat)

    assert_response :success
    assert_no_match "new_message", @response.body
    assert_match I18n.t("messages.composer.exhausted", count: User::DAILY_MESSAGE_LIMIT), @response.body
  end
end
