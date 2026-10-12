require "test_helper"

class AccountDeletionJobTest < ActiveJob::TestCase
  test "erases the account and everything it owns" do
    user = users(:one)
    chat = user.chats.create!(model: "gpt-4o-mini")

    AccountDeletionJob.perform_now(user)

    assert_not User.exists?(user.id)
    assert_not Chat.exists?(chat.id)
  end

  test "drops the job without retrying when the account is already gone" do
    user = users(:one)
    serialized = AccountDeletionJob.new(user).serialize
    user.destroy!

    ActiveJob::Base.execute(serialized)

    assert_no_enqueued_jobs only: AccountDeletionJob
  end
end
