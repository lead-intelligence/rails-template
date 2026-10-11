require "test_helper"

class MessageTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  test "broadcasts itself synchronously when created, before any later chunk appends" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")

    assert_broadcasts("chat_#{chat.id}", 1) do
      chat.messages.create!(role: :assistant, content: "Hello")
    end
  end

  test "broadcasts itself synchronously when updated" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    message = chat.messages.create!(role: :assistant, content: "")

    assert_broadcasts("chat_#{chat.id}", 1) do
      message.update!(content: "Hello world")
    end
  end

  test "broadcasts updates as a versioned append into the message list, not a replace" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    message = chat.messages.create!(role: :assistant, content: "")

    clear_messages("chat_#{chat.id}")
    message.update!(content: "Hello world")
    raw_broadcasts = broadcasts("chat_#{chat.id}")

    assert_equal 1, raw_broadcasts.size
    broadcasted = JSON.parse(raw_broadcasts.first)
    assert_match(/action="append"/, broadcasted)
    assert_match(/target="chat_#{chat.id}_messages"/, broadcasted)
    assert_match(/id="message_#{message.id}"/, broadcasted)
    assert_match(/data-version="#{Regexp.escape(message.broadcast_version.to_s)}"/, broadcasted)
  end

  test "broadcast_version increases after an update so a stale broadcast can be detected" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    message = chat.messages.create!(role: :assistant, content: "")
    original_version = message.broadcast_version

    message.update!(content: "Hello world")

    assert_operator message.broadcast_version, :>, original_version
  end

  test "broadcasts a remove synchronously when destroyed" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    message = chat.messages.create!(role: :assistant, content: "Hello")

    assert_broadcasts("chat_#{chat.id}", 1) do
      message.destroy!
    end
  end

  test "does not broadcast technical tool-call details when a message updates in a support chat" do
    chat = users(:one).chats.create!(support: true)
    message = chat.messages.create!(role: :assistant, content: "")
    message.ruby_llm_tool_calls.create!(tool_call_id: "call_1", name: "create_support_ticket", arguments: { title: "x", summary: "y" })

    clear_messages("chat_#{chat.id}")
    message.update!(updated_at: Time.current)
    raw_broadcasts = broadcasts("chat_#{chat.id}")

    assert_equal 1, raw_broadcasts.size
    broadcasted = JSON.parse(raw_broadcasts.first)
    assert_no_match "create_support_ticket", broadcasted
    assert_match(/id="message_#{message.id}"/, broadcasted)
    assert_match(/data-version="#{Regexp.escape(message.broadcast_version.to_s)}"/, broadcasted)
  end

  test "renders normally for a system message in a regular chat" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    message = chat.messages.create!(role: :system, content: "Be concise.")

    assert_equal "messages/system", message.to_partial_path
  end

  test "hides a system message from the person in a support chat" do
    chat = users(:one).chats.create!(support: true)
    message = chat.messages.create!(role: :system, content: "Never mention code.")

    assert_equal "messages/blank", message.to_partial_path
  end

  test "hides a tool result message from the person in a support chat" do
    chat = users(:one).chats.create!(support: true)
    message = chat.messages.create!(role: :tool, content: "Ticket filed.")

    assert_equal "messages/blank", message.to_partial_path
  end

  test "hides a tool call message from the person in a support chat" do
    chat = users(:one).chats.create!(support: true)
    message = chat.messages.create!(role: :assistant, content: "")
    message.ruby_llm_tool_calls.create!(tool_call_id: "call_1", name: "create_support_ticket", arguments: { title: "x", summary: "y" })

    assert_equal "messages/blank", message.to_partial_path
  end

  test "shows a plain assistant reply to the person in a support chat" do
    chat = users(:one).chats.create!(support: true)
    message = chat.messages.create!(role: :assistant, content: "Thanks, I've filed this for the team.")

    assert_equal "messages/assistant", message.to_partial_path
  end
end
