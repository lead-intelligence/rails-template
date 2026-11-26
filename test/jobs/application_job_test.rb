require "test_helper"

class ApplicationJobTest < ActiveJob::TestCase
  test "discards jobs whose record was destroyed before it ran" do
    chat = users(:one).chats.create!(model: "gpt-5.4-nano")

    GenerateChatTitleJob.perform_later(chat)
    chat.destroy!

    assert_nothing_raised { perform_enqueued_jobs(only: GenerateChatTitleJob) }
  end
end
