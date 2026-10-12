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

  test "rejects a text file sent as a png pending photo" do
    chat = users(:one).chats.create!(support: true)
    chat.pending_photos.attach(io: StringIO.new("plain text"), filename: "avatar.png", content_type: "image/png")

    assert_not chat.valid?
    assert chat.errors.of_kind?(:pending_photos, :content_type_spoofed)
  end

  test "rejects a non-image pending photo" do
    chat = users(:one).chats.create!(support: true)
    chat.pending_photos.attach(io: StringIO.new("plain text"), filename: "notes.txt", content_type: "text/plain")
    assert_not chat.valid?
  end

  test "rejects an oversize pending photo" do
    chat = users(:one).chats.create!(support: true)
    chat.pending_photos.attach(io: StringIO.new(file_fixture("avatar.png").binread + ("\0" * 6.megabytes)), filename: "big.png", content_type: "image/png")
    assert_not chat.valid?
    assert chat.errors.of_kind?(:pending_photos, :file_size_not_less_than)
  end

  test "offers only the chat models of the configured provider" do
    models = Chat.selectable_models

    assert models.any?
    assert models.all? { |model| model.type == :chat && model.provider == Chat::PROVIDER.to_s }
    assert_operator models.count, :<, RubyLLM.models.chat_models.count
  end

  test "offers only models that answer in text" do
    ids = Chat.selectable_models.map(&:id)

    assert_includes ids, "gpt-4o-mini"
    assert_empty ids & %w[tts-1 whisper-1 gpt-4o-mini-transcribe omni-moderation-latest gpt-image-2 gpt-realtime]
  end

  test "destroying a conversation keeps the ticket it filed" do
    chat = users(:one).chats.create!(support: true)
    feedback = users(:one).feedbacks.create!(message: "No puedo entrar", chat: chat)

    chat.destroy!

    assert_nil feedback.reload.chat
  end
end
