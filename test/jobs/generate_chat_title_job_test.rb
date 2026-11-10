require "test_helper"

class GenerateChatTitleJobTest < ActiveJob::TestCase
  test "titles the chat from its first user message" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    chat.messages.create!(role: "user", content: "How do I deploy Rails with Kamal?")
    stub_openai_chat(content: { title: "Deploying Rails with Kamal", tags: [ "rails", "kamal" ] }.to_json)
    GenerateChatTitleJob.perform_now(chat)
    assert_equal "Deploying Rails with Kamal", chat.reload.title
  end

  test "keeps an existing title" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini", title: "Kept")
    GenerateChatTitleJob.perform_now(chat)
    assert_equal "Kept", chat.reload.title
  end

  test "does nothing without a user message yet" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    GenerateChatTitleJob.perform_now(chat)
    assert_nil chat.reload.title
  end

  test "records the title's usage against the chat's owner" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    chat.messages.create!(role: "user", content: "How do I deploy Rails with Kamal?")
    stub_openai_chat(content: { title: "Deploying Rails with Kamal", tags: [ "rails" ] }.to_json)

    assert_difference -> { users(:one).ruby_llm_usages.count }, 1 do
      GenerateChatTitleJob.perform_now(chat)
    end
  end
end
