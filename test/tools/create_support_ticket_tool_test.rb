require "test_helper"

class CreateSupportTicketToolTest < ActiveSupport::TestCase
  test "is registered with the LLM under a human-friendly name" do
    tool = CreateSupportTicketTool.new(users(:one).chats.create!(support: true))
    assert_equal "create_support_ticket", tool.name
  end

  test "creates a feedback for the user it was built for, from the title and summary" do
    tool = CreateSupportTicketTool.new(users(:one).chats.create!(support: true))

    assert_difference("users(:one).feedbacks.count", 1) do
      tool.execute(title: "Chat page is slow", summary: "Pages take a long time to load for this person.")
    end

    feedback = users(:one).feedbacks.last
    assert_includes feedback.message, "Chat page is slow"
    assert_includes feedback.message, "Pages take a long time to load for this person."
  end

  test "files a summary longer than the feedback limit, cut to the limit" do
    tool = CreateSupportTicketTool.new(users(:one).chats.create!(support: true))

    result = tool.execute(title: "Long report", summary: "a" * Feedback::MESSAGE_MAX_LENGTH)

    feedback = users(:one).feedbacks.last
    assert_equal Feedback::MESSAGE_MAX_LENGTH, feedback.message.length
    assert feedback.message.start_with?("Long report\n\naaa")
    assert_equal "Got it - I've passed this along to the team. Thank you!", result
  end

  test "returns a human-friendly confirmation with no technical details" do
    tool = CreateSupportTicketTool.new(users(:one).chats.create!(support: true))
    result = tool.execute(title: "Chat page is slow", summary: "Pages take a long time to load.")

    assert_equal "Got it - I've passed this along to the team. Thank you!", result
  end

  test "copies the chat's ticket context onto the created feedback" do
    chat = users(:one).chats.create!(support: true, ticket_context: { "page_url" => "https://example.com/chats/1", "user_agent" => "TestBrowser/1.0", "viewport" => "1512x982" })
    tool = CreateSupportTicketTool.new(chat)

    tool.execute(title: "Chat page is slow", summary: "Pages take a long time to load.")

    feedback = users(:one).feedbacks.last
    assert_equal chat.ticket_context, feedback.context
  end

  test "leaves the feedback context blank when the chat has none" do
    chat = users(:one).chats.create!(support: true)
    tool = CreateSupportTicketTool.new(chat)

    tool.execute(title: "Chat page is slow", summary: "Pages take a long time to load.")

    feedback = users(:one).feedbacks.last
    assert_nil feedback.context
  end

  test "attaches the chat's pending photos to the feedback, clears the pending set, and confirms the count" do
    chat = users(:one).chats.create!(support: true)
    chat.pending_photos.attach(io: File.open(file_fixture("avatar.png")), filename: "avatar.png", content_type: "image/png")
    tool = CreateSupportTicketTool.new(chat)

    result = tool.execute(title: "Broken layout", summary: "Something looks off.")

    feedback = users(:one).feedbacks.last
    assert feedback.photos.attached?
    assert_equal "avatar.png", feedback.photos.first.filename.to_s
    assert_not chat.pending_photos.attached?
    assert feedback.photos.first.blob.persisted?
    assert_equal "Got it - I've passed this along to the team, including your 1 photo. Thank you!", result
  end

  test "confirms multiple attached photos with correct pluralization" do
    chat = users(:one).chats.create!(support: true)
    chat.pending_photos.attach([
      { io: File.open(file_fixture("avatar.png")), filename: "one.png", content_type: "image/png" },
      { io: File.open(file_fixture("avatar.png")), filename: "two.png", content_type: "image/png" }
    ])
    tool = CreateSupportTicketTool.new(chat)

    result = tool.execute(title: "Broken layout", summary: "Something looks off.")

    assert_equal "Got it - I've passed this along to the team, including your 2 photos. Thank you!", result
  end

  test "does nothing with photos when the chat has none pending" do
    chat = users(:one).chats.create!(support: true)
    tool = CreateSupportTicketTool.new(chat)

    result = tool.execute(title: "Chat page is slow", summary: "Pages take a long time to load.")

    feedback = users(:one).feedbacks.last
    assert_not feedback.photos.attached?
    assert_equal "Got it - I've passed this along to the team. Thank you!", result
  end

  test "leaves pending photos in place and stays honest when attaching them to the feedback fails" do
    chat = users(:one).chats.create!(support: true)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("not a photo"), filename: "notes.txt", content_type: "text/plain")
    chat.pending_photos_attachments.create!(blob: blob)
    tool = CreateSupportTicketTool.new(chat)

    result = tool.execute(title: "Broken layout", summary: "Something looks off.")

    feedback = users(:one).feedbacks.last
    assert_not feedback.photos.attached?
    assert_equal 0, ActiveStorage::Attachment.where(record_type: "Feedback", name: "photos").count
    assert chat.pending_photos.attached?
    assert_equal "Got it - I've passed this along to the team. Thank you!", result
  end
end
