require "test_helper"

class NotificationsHelperTest < ActionView::TestCase
  setup { Current.session = users(:one).sessions.create! }
  teardown { Current.session = nil }

  test "unread_notifications_count counts only unread notifications for the current user" do
    TestNotifier.deliver(users(:one))
    TestNotifier.deliver(users(:two))

    assert_equal 1, unread_notifications_count
  end

  test "recent_notifications returns the current user's notifications newest first" do
    older = TestNotifier.deliver(users(:one)).notifications.first
    newer = TestNotifier.deliver(users(:one)).notifications.first
    older.update_columns(created_at: 1.hour.ago)

    assert_equal [ newer, older ], recent_notifications.to_a
  end

  test "the bell counts unread notifications from an index alone" do
    plan = query_plan_of { unread_notifications_count }

    assert plan.any? { |step| step.include?("COVERING INDEX index_noticed_notifications_on_recipient_and_read_at") }, plan.inspect
  end

  test "the bell reads the newest notifications in index order instead of sorting them all" do
    plan = query_plan_of { recent_notifications }

    assert plan.any? { |step| step.include?("index_noticed_notifications_on_recipient_and_created_at") }, plan.inspect
    assert plan.none? { |step| step.include?("TEMP B-TREE") }, plan.inspect
  end

  private

  def query_plan_of(&block)
    queries = []
    capture = ->(*, payload) { queries << payload if payload[:sql].include?(%(FROM "noticed_notifications")) }
    ActiveSupport::Notifications.subscribed(capture, "sql.active_record", &block)
    query = queries.sole
    ActiveRecord::Base.connection.select_rows("EXPLAIN QUERY PLAN #{query[:sql]}", "SQL", query[:binds]).map(&:last)
  end
end
