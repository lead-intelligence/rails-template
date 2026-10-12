require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "purge_inactive destroys sessions unused past the inactivity limit" do
    stale = session_last_used((Session::INACTIVITY_LIMIT + 1.day).ago)

    Session.purge_inactive

    assert_not Session.exists?(stale.id)
  end

  test "purge_inactive keeps sessions used inside the inactivity limit" do
    recent = session_last_used((Session::INACTIVITY_LIMIT - 1.day).ago)

    Session.purge_inactive

    assert Session.exists?(recent.id)
  end

  test "a session unused past the inactivity limit is inactive" do
    assert session_last_used((Session::INACTIVITY_LIMIT + 1.day).ago).inactive?
    assert_not session_last_used(1.day.ago).inactive?
  end

  test "recording activity touches a session last used before today" do
    session = session_last_used(2.days.ago)

    session.record_activity

    assert_in_delta Time.current, session.reload.updated_at, 1.second
  end

  test "recording activity writes nothing when the session was used within the day" do
    session = session_last_used(1.hour.ago)

    assert_no_queries { session.record_activity }
  end

  private

  def session_last_used(time)
    users(:one).sessions.create!.tap { |session| session.update_column(:updated_at, time) }
  end
end
