require "test_helper"

class TimeZoneTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  BUENOS_AIRES = "America/Argentina/Buenos_Aires"

  test "remembers the zone the browser reports" do
    sign_in_as users(:one)
    cookies[:time_zone] = BUENOS_AIRES

    get chats_url

    assert_equal BUENOS_AIRES, users(:one).reload.time_zone
  end

  test "ignores a zone that does not exist" do
    sign_in_as users(:one)
    cookies[:time_zone] = "Mars/Olympus_Mons"

    get chats_url

    assert_nil users(:one).reload.time_zone
  end

  test "shows times in the person's zone" do
    users(:one).update!(time_zone: BUENOS_AIRES)
    sign_in_as users(:one)
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    chat.messages.create!(role: :user, content: "Hi", created_at: Time.utc(2026, 11, 24, 1, 30))

    get chat_url(chat)

    assert_select "time", text: "22:30"
  end

  test "dates the blog in an anonymous visitor's zone" do
    cookies[:time_zone] = BUENOS_AIRES
    Railspress::Post.create!(title: "Late Post", status: :published, published_at: Time.utc(2026, 11, 24, 1, 30))

    get blog_url

    assert_includes response.body, I18n.l(Date.new(2026, 11, 23), format: :long, locale: I18n.default_locale)
  end

  test "counts the daily quota on the person's day, not the UTC one" do
    sign_in_as users(:one)
    cookies[:time_zone] = BUENOS_AIRES
    chat = users(:one).chats.create!(model: "gpt-4o-mini")

    travel_to Time.utc(2026, 11, 24, 1, 0) do
      post chat_messages_url(chat), params: { message: { content: "Hi" } }
    end

    assert_equal Date.new(2026, 11, 23), users(:one).reload.messages_sent_on
  end
end
