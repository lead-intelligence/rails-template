require "test_helper"

class SupportAgentTest < ActiveSupport::TestCase
  test "configures itself on the Chat persistence model" do
    assert_equal Chat, SupportAgent.chat_class
  end

  test "finding a support chat applies the binding rule and support context as instructions" do
    chat = users(:one).chats.create!(support: true)

    configured_chat = SupportAgent.find(chat.id)

    system_message = configured_chat.to_llm.messages.find { |message| message.role == :system }
    assert_includes system_message.content, SupportContext::BINDING_RULE
    assert_includes system_message.content, SupportContext.content
  end

  test "finding a support chat attaches the ticket-filing tool scoped to that chat's user" do
    chat = users(:one).chats.create!(support: true)

    configured_chat = SupportAgent.find(chat.id)

    tool = configured_chat.to_llm.tools[:create_support_ticket]
    assert_instance_of CreateSupportTicketTool, tool
    assert_equal users(:one), tool.instance_variable_get(:@user)
  end

  test "finding the same support chat twice does not duplicate the persisted system message" do
    chat = users(:one).chats.create!(support: true)

    SupportAgent.find(chat.id)
    SupportAgent.find(chat.id)

    assert_equal 0, chat.messages.where(role: "system").count
  end
end
