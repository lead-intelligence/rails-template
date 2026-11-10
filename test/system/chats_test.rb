require "application_system_test_case"

class ChatsTest < ApplicationSystemTestCase
  test "visits the new chat page" do
    sign_in_via_browser(users(:one))

    visit new_chat_url

    assert_text t("chats.new.title")
  end

  test "sending a message streams the assistant's reply into the chat" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    sign_in_via_browser(users(:one))
    stub_openai_chat(content: { title: "Deploying with Kamal", tags: [ "kamal" ] }.to_json)
    stub_openai_chat_stream(chunks: [ "Sure", ", here", " is how." ])

    visit chat_url(chat)
    fill_in t("messages.form.content_label"), with: "How do I deploy with Kamal?"
    click_button t("messages.form.submit")

    assert_text "How do I deploy with Kamal?"
    assert_text "Sure, here is how."
  end

  test "a long chat loads its older messages on demand" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    oldest = chat.messages.create!(role: :user, content: "The very first question")
    ChatsController::MESSAGES_PER_PAGE.times { |index| chat.messages.create!(role: :assistant, content: "Reply #{index}") }
    sign_in_via_browser(users(:one))

    visit chat_url(chat)
    assert_no_text oldest.content
    click_link t("chats.older_messages.load")

    assert_text oldest.content
    assert_no_link t("chats.older_messages.load")
  end

  test "a failed completion shows a human-friendly failure instead of leaking the error" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    sign_in_via_browser(users(:one))
    stub_openai_chat_error(status: 500)

    visit chat_url(chat)

    without_raising_server_errors do
      fill_in t("messages.form.content_label"), with: "How do I deploy with Kamal?"
      click_button t("messages.form.submit")

      assert_text "How do I deploy with Kamal?"
      assert_text t("messages.failure.body")
    end
  end
end
