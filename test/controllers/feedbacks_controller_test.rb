require "test_helper"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  test "requires authentication" do
    get new_feedback_url
    assert_redirected_to new_session_url
  end

  test "shows the feedback form" do
    sign_in_as users(:one)
    get new_feedback_url
    assert_response :success
    assert_select "textarea[maxlength=?][aria-describedby=feedback_message_hint]", Feedback::MESSAGE_MAX_LENGTH.to_s
    assert_select "#feedback_message_hint", I18n.t("feedbacks.new.message_hint", count: ActiveSupport::NumberHelper.number_to_delimited(Feedback::MESSAGE_MAX_LENGTH))
  end

  test "creates feedback scoped to the current user and redirects with a success flash" do
    sign_in_as users(:one)
    assert_difference("Feedback.count") do
      post feedback_url, params: { feedback: { message: "The chat page is slow" } }
    end
    feedback = Feedback.last
    assert_equal users(:one), feedback.user
    assert_redirected_to root_url
    assert_equal I18n.t("feedbacks.create.notice"), flash[:notice]
  end

  test "attaches uploaded photos to the feedback" do
    sign_in_as users(:one)
    photo = fixture_file_upload("test/fixtures/files/avatar.png", "image/png")

    post feedback_url, params: { feedback: { message: "Broken layout", photos: [ photo ] } }

    assert_equal 1, Feedback.last.photos.count
  end

  test "does not create feedback with a blank message" do
    sign_in_as users(:one)
    assert_no_difference("Feedback.count") do
      post feedback_url, params: { feedback: { message: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "does not create feedback with an invalid photo and shows the error" do
    sign_in_as users(:one)
    photo = fixture_file_upload("test/fixtures/files/note.txt", "text/plain")

    assert_no_difference("Feedback.count") do
      post feedback_url, params: { feedback: { message: "Broken layout", photos: [ photo ] } }
    end

    assert_response :unprocessable_entity
    assert_includes @response.body, "Photos"
  end

  test "rate limits repeated feedback submissions" do
    sign_in_as users(:one)
    5.times { post feedback_url, params: { feedback: { message: "The chat page is slow" } } }

    assert_no_difference("Feedback.count") do
      post feedback_url, params: { feedback: { message: "The chat page is slow" } }
    end

    assert_redirected_to new_feedback_url
    assert_equal I18n.t("feedbacks.rate_limit"), flash[:alert]
  end

  test "the rate limit follows the person, not the session" do
    sign_in_as users(:one)
    5.times { post feedback_url, params: { feedback: { message: "The chat page is slow" } } }

    delete session_url
    sign_in_as users(:two)

    assert_difference("Feedback.count") do
      post feedback_url, params: { feedback: { message: "The chat page is slow" } }
    end
  end
end
