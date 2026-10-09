require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  test "requires a message" do
    feedback = users(:one).feedbacks.build(message: "")
    assert_not feedback.valid?
    assert_includes feedback.errors[:message], I18n.t("errors.messages.blank")
  end

  test "rejects a message longer than the limit" do
    assert users(:one).feedbacks.build(message: "a" * Feedback::MESSAGE_MAX_LENGTH).valid?

    feedback = users(:one).feedbacks.build(message: "a" * (Feedback::MESSAGE_MAX_LENGTH + 1))
    assert_not feedback.valid?
    assert_includes feedback.errors[:message], I18n.t("errors.messages.too_long", count: Feedback::MESSAGE_MAX_LENGTH)
  end

  test "is valid with a user and a message" do
    feedback = users(:one).feedbacks.build(message: "The chat page is slow")
    assert feedback.valid?
  end

  test "accepts a png photo" do
    feedback = users(:one).feedbacks.build(message: "Broken layout")
    feedback.photos.attach(io: File.open(file_fixture("avatar.png")), filename: "avatar.png", content_type: "image/png")
    assert feedback.valid?
  end

  test "rejects a non-image photo" do
    feedback = users(:one).feedbacks.build(message: "Broken layout")
    feedback.photos.attach(io: StringIO.new("plain text"), filename: "notes.txt", content_type: "text/plain")
    assert_not feedback.valid?
  end

  test "rejects an oversize photo" do
    feedback = users(:one).feedbacks.build(message: "Broken layout")
    feedback.photos.attach(io: StringIO.new("x" * 6.megabytes), filename: "big.png", content_type: "image/png")
    assert_not feedback.valid?
  end

  test "enqueues CreateFeedbackIssueJob after create" do
    assert_enqueued_with(job: CreateFeedbackIssueJob) do
      users(:one).feedbacks.create!(message: "The chat page is slow")
    end
  end

  test "defaults to open" do
    feedback = users(:one).feedbacks.create!(message: "The chat page is slow")
    assert feedback.open?
    assert_nil feedback.resolved_at
  end

  test "resolve! marks the feedback resolved and stamps resolved_at" do
    feedback = users(:one).feedbacks.create!(message: "The chat page is slow")
    feedback.resolve!
    assert feedback.resolved?
    assert_not_nil feedback.resolved_at
  end

  test "resolve! is idempotent" do
    feedback = users(:one).feedbacks.create!(message: "The chat page is slow")
    feedback.resolve!
    first_resolved_at = feedback.resolved_at

    feedback.resolve!

    assert feedback.resolved?
    assert_equal first_resolved_at, feedback.resolved_at
  end
end
