require "test_helper"

class AccountDeletionJobTest < ActiveJob::TestCase
  test "erases the account and everything it owns" do
    user = users(:one)
    chat = user.chats.create!(model: "gpt-5.4-nano")

    AccountDeletionJob.perform_now(user)

    assert_not User.exists?(user.id)
    assert_not Chat.exists?(chat.id)
  end

  test "erases each chat in its own short transaction, so other writes are not locked out for the whole account" do
    user = users(:one)
    2.times { user.chats.create!(model: "gpt-5.4-nano") }
    chat_count = user.chats.count
    savepoints = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      savepoints << payload[:sql] if payload[:sql].match?(/\ASAVEPOINT /)
    end

    AccountDeletionJob.perform_now(user)

    assert_not User.exists?(user.id)
    assert_operator savepoints.size, :>, chat_count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  test "drops the job without retrying when the account is already gone" do
    user = users(:one)
    serialized = AccountDeletionJob.new(user).serialize
    user.destroy!

    ActiveJob::Base.execute(serialized)

    assert_no_enqueued_jobs only: AccountDeletionJob
  end
end
