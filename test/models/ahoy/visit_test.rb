require "test_helper"

class Ahoy::VisitTest < ActiveSupport::TestCase
  test "purge_expired removes visits past the retention window along with their events" do
    expired = visit_at((Ahoy::Visit::RETENTION + 1.day).ago)
    expired.events.create!(name: "Signed in", time: expired.started_at)

    assert_difference [ "Ahoy::Visit.count", "Ahoy::Event.count" ], -1 do
      Ahoy::Visit.purge_expired
    end
  end

  test "purge_expired keeps visits inside the retention window" do
    recent = visit_at(1.day.ago)
    recent.events.create!(name: "Signed in", time: recent.started_at)

    assert_no_difference [ "Ahoy::Visit.count", "Ahoy::Event.count" ] do
      Ahoy::Visit.purge_expired
    end
  end

  test "purge_expired finds expired visits through the started_at index instead of scanning every visit" do
    plan = ActiveRecord::Base.connection.select_rows("EXPLAIN QUERY PLAN #{Ahoy::Visit.expired.to_sql}").map(&:last)

    assert plan.any? { |step| step.include?("index_ahoy_visits_on_started_at") }, plan.inspect
  end

  test "a deleted user takes their visits and events with them" do
    user = users(:one)
    visit = visit_at(1.day.ago, user: user)
    visit.events.create!(name: "Signed in", time: visit.started_at, user: user)

    assert_difference [ "Ahoy::Visit.count", "Ahoy::Event.count" ], -1 do
      user.destroy
    end
  end

  private

  def visit_at(started_at, user: nil)
    Ahoy::Visit.create!(visit_token: SecureRandom.uuid, visitor_token: SecureRandom.uuid, started_at: started_at, user: user)
  end
end
