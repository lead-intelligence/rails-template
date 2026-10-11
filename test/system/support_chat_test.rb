require "application_system_test_case"

class SupportChatTest < ApplicationSystemTestCase
  test "the widget opens on the conversation list and carries the page context into a new one" do
    sign_in_via_browser(users(:one))

    frame = find("turbo-frame#support_chat", visible: :all)
    assert_nil frame[:src]

    click_button t("support_chats.widget.support")
    assert_selector "dialog.modal", visible: true

    frame_src = URI.parse(find("turbo-frame#support_chat", visible: :all)[:src])
    assert_equal support_chats_path, frame_src.path
    context = Rack::Utils.parse_nested_query(frame_src.query)["context"]
    assert context["page_url"].present?
    assert context["user_agent"].present?
    assert context["viewport"].present?

    within "dialog.modal" do
      click_button t("support_chats.index.start")
      assert_selector "[id^='new_message_']"
    end

    chat = users(:one).chats.support.sole
    assert_equal context["page_url"], chat.ticket_context["page_url"]
  end

  test "sending a message shows the stubbed human-friendly reply without leaving the widget" do
    sign_in_via_browser(users(:one))

    stub_openai_chat_stream(chunks: [ "Thanks for reaching out, let's sort this out together." ])

    click_button t("support_chats.widget.support")
    within "dialog.modal" do
      click_button t("support_chats.index.start")
      assert_selector "turbo-cable-stream-source[connected]", visible: :all
      fill_in t("support_chats.composer.label"), with: "The chat page loads slowly for me"
      click_button t("support_chats.composer.send")

      assert_text "The chat page loads slowly for me"
      assert_text "Thanks for reaching out, let's sort this out together."
    end
  end

  test "sending a message from the support widget leaves the chat page's own composer untouched" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    sign_in_via_browser(users(:one))
    stub_openai_chat_stream(chunks: [ "Thanks for reaching out, let's sort this out together." ])

    visit chat_url(chat)
    assert_selector "#composer_#{chat.id} input[type=submit]"

    click_button t("support_chats.widget.support")
    within "dialog.modal" do
      click_button t("support_chats.index.start")
      assert_selector "turbo-cable-stream-source[connected]", visible: :all
      fill_in t("support_chats.composer.label"), with: "The chat page loads slowly for me"
      click_button t("support_chats.composer.send")

      assert_text "Thanks for reaching out, let's sort this out together."
    end

    assert_selector "#composer_#{chat.id} input[type=submit]"
  end

  test "a failed reply shows a human-friendly failure and leaves no pending spinner" do
    sign_in_via_browser(users(:one))

    stub_openai_chat_error(status: 500)

    click_button t("support_chats.widget.support")
    within "dialog.modal" do
      click_button t("support_chats.index.start")
      assert_selector "[id^='new_message_']"
      assert_selector "turbo-cable-stream-source[connected]", visible: :all
    end

    without_raising_server_errors do
      within "dialog.modal" do
        fill_in t("support_chats.composer.label"), with: "The chat page loads slowly for me"
        click_button t("support_chats.composer.send")

        assert_selector ".chat-start .chat-bubble", text: t("messages.failure.body")
        assert_selector "[data-support-conversation-target='pending'].hidden", visible: :all
      end
    end
  end

  test "past conversations are listed and can be reopened" do
    user = users(:one)
    past = user.chats.create!(support: true)
    past.messages.create!(role: :user, content: "Mi factura salio mal")

    sign_in_via_browser(user)

    click_button t("support_chats.widget.support")
    within "dialog.modal" do
      click_link "Mi factura salio mal"
      assert_selector "[id^='new_message_']"
      assert_text "Mi factura salio mal"
    end
  end

  test "attaching a photo before filing a ticket carries the photo to the resulting feedback" do
    sign_in_via_browser(users(:one))

    stub_openai_chat_stream_with_tool_call(
      tool_name: "create_support_ticket",
      arguments: { title: "Broken layout", summary: "The layout breaks on this page." },
      chunks: [ "Got it - I've passed this along to the team. Thank you!" ]
    )

    click_button t("support_chats.widget.support")
    within "dialog.modal" do
      click_button t("support_chats.index.start")
      chat = users(:one).chats.support.sole
      attach_file "chat_pending_photos", file_fixture("avatar.png"), make_visible: true
      assert_text t("support_chats.photos.attached", count: 1)
      assert_selector "turbo-cable-stream-source[connected]", visible: :all

      fill_in t("support_chats.composer.label"), with: "The layout looks broken on this page"
      click_button t("support_chats.composer.send")

      assert_text "Got it - I've passed this along to the team. Thank you!"
      assert chat
    end

    feedback = Feedback.last
    assert feedback.photos.attached?
  end
end
