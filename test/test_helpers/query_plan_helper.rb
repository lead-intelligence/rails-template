module QueryPlanHelper
  def query_plan_of_first_select_from(table, &block)
    statements = []
    recorder = ->(*, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(recorder, "sql.active_record", &block)
    sql = statements.find { |statement| statement.start_with?("SELECT \"#{table}\".") }

    ActiveRecord::Base.connection.select_rows("EXPLAIN QUERY PLAN #{sql}").map(&:last)
  end
end
