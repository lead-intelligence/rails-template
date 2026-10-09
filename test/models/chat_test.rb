require "test_helper"

class ChatTest < ActiveSupport::TestCase
  test "ask persists user and assistant messages via stubbed OpenAI" do
    stub_openai_chat(content: "Hello from the stub")
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    chat.ask("Say hello")
    assert_equal [ "user", "assistant" ], chat.messages.order(:created_at).pluck(:role)
    assert_includes chat.messages.last.content, "Hello from the stub"
  end

  test "support scope returns only chats flagged as support chats" do
    support_chat = users(:one).chats.create!(support: true)
    users(:one).chats.create!(model: "gpt-4o-mini")

    assert_equal [ support_chat ], users(:one).chats.support.to_a
  end

  test "is not a support chat by default" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    assert_not chat.support?
  end

  test "accepts a png pending photo" do
    chat = users(:one).chats.create!(support: true)
    chat.pending_photos.attach(io: File.open(file_fixture("avatar.png")), filename: "avatar.png", content_type: "image/png")
    assert chat.valid?
  end

  test "rejects a non-image pending photo" do
    chat = users(:one).chats.create!(support: true)
    chat.pending_photos.attach(io: StringIO.new("plain text"), filename: "notes.txt", content_type: "text/plain")
    assert_not chat.valid?
  end

  test "rejects an oversize pending photo" do
    chat = users(:one).chats.create!(support: true)
    chat.pending_photos.attach(io: StringIO.new("x" * 6.megabytes), filename: "big.png", content_type: "image/png")
    assert_not chat.valid?
  end

  test "destroying a conversation keeps the ticket it filed" do
    chat = users(:one).chats.create!(support: true)
    feedback = users(:one).feedbacks.create!(message: "No puedo entrar", chat: chat)

    chat.destroy!

    assert_nil feedback.reload.chat
  end
end
