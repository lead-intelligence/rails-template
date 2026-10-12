require "test_helper"

class ErrorFeedTest < ActiveSupport::TestCase
  test "finds when each error was last seen through an index instead of reading every occurrence" do
    error = SolidErrors::Error.create!(exception_class: "NoMethodError", message: "boom", severity: "error", fingerprint: SecureRandom.hex(32))
    error.occurrences.create!(backtrace: "", context: {})
    queries = []
    capture = ->(*, payload) { queries << payload if payload[:sql].include?("MAX(") }

    ActiveSupport::Notifications.subscribed(capture, "sql.active_record") { ErrorFeed.new(since: 0).page }

    last_seen = queries.sole
    plan = ActiveRecord::Base.connection.select_rows("EXPLAIN QUERY PLAN #{last_seen[:sql]}", "SQL", last_seen[:binds]).map(&:last)
    assert plan.any? { |step| step.include?("COVERING INDEX index_solid_errors_occurrences_on_error_id_and_created_at") }, plan.inspect
  end
end
