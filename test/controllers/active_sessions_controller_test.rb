require "test_helper"

class ActiveSessionsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  test "requires authentication" do
    get active_sessions_url
    assert_redirected_to new_session_url
  end

  test "lists only the current user's sessions and marks this device" do
    sign_in_as users(:one)
    users(:one).sessions.create!(ip_address: "10.0.0.1", user_agent: "Other Browser")
    users(:two).sessions.create!(ip_address: "10.0.0.2", user_agent: "Someone Else")

    get active_sessions_url

    assert_response :success
    assert_select "#sessions li", count: 2
    assert_select ".badge", count: 1
    assert_select "form[action=?]", revoke_others_active_sessions_path, count: 1
  end

  test "states the inactivity rule from the limit the model enforces" do
    sign_in_as users(:one)

    get active_sessions_url

    assert_select "p", text: I18n.t("active_sessions.index.inactivity_rule", days: Session::INACTIVITY_LIMIT.in_days.to_i)
  end

  test "counts the sessions once and reads one page of them" do
    sign_in_as users(:one)
    users(:one).sessions.create!(ip_address: "10.0.0.1", user_agent: "Other Browser")

    assert_queries_match(/FROM "sessions" WHERE "sessions"."user_id"/, count: 2) { get active_sessions_url }
  end

  test "hides the revoke_others button when there is only one session" do
    sign_in_as users(:one)

    get active_sessions_url

    assert_response :success
    assert_select "#sessions li", count: 1
    assert_select "form[action=?]", revoke_others_active_sessions_path, count: 0
  end

  test "lists one page of sessions and links to the next" do
    sign_in_as users(:one)
    ActiveSessionsController::PER_PAGE.times { |index| users(:one).sessions.create!(ip_address: "10.0.0.#{index}", user_agent: "Browser #{index}") }

    get active_sessions_url

    assert_select "#sessions li", count: ActiveSessionsController::PER_PAGE
    assert_select "nav.pagy a[rel=next][href=?]", active_sessions_path(page: 2)
  end

  test "lists the remaining sessions on the second page and still offers to revoke the others" do
    sign_in_as users(:one)
    ActiveSessionsController::PER_PAGE.times { |index| users(:one).sessions.create!(ip_address: "10.0.0.#{index}", user_agent: "Browser #{index}") }

    get active_sessions_url(page: 2)

    assert_select "#sessions li", count: 1
    assert_select "form[action=?]", revoke_others_active_sessions_path, count: 1
  end

  test "cannot revoke another user's session" do
    sign_in_as users(:one)
    other_session = users(:two).sessions.create!(ip_address: "10.0.0.2", user_agent: "Someone Else")

    delete active_session_url(other_session)

    assert_response :not_found
    assert users(:two).sessions.exists?(other_session.id)
  end

  test "revokes another session and keeps the current cookie" do
    sign_in_as users(:one)
    other_session = users(:one).sessions.create!(ip_address: "10.0.0.1", user_agent: "Other Browser")

    assert_difference("Session.count", -1) do
      delete active_session_url(other_session)
    end

    assert_response :see_other
    assert_redirected_to active_sessions_url
    assert cookies[:session_id].present?
  end

  test "revoking the current session deletes the cookie and redirects to sign-in" do
    sign_in_as users(:one)
    current_session = users(:one).sessions.sole

    delete active_session_url(current_session)

    assert_response :see_other
    assert_redirected_to new_session_url
    assert_not cookies[:session_id].present?
    assert_not Session.exists?(current_session.id)
  end

  test "revoke_others deletes every other session but keeps the current one and other users' sessions" do
    sign_in_as users(:one)
    current_session = users(:one).sessions.sole
    users(:one).sessions.create!(ip_address: "10.0.0.1", user_agent: "Other Browser")
    other_user_session = users(:two).sessions.create!(ip_address: "10.0.0.2", user_agent: "Someone Else")

    delete revoke_others_active_sessions_url

    assert_response :see_other
    assert_redirected_to active_sessions_url
    assert_equal [ current_session ], users(:one).sessions.reload.to_a
    assert users(:two).sessions.exists?(other_user_session.id)
  end
end
