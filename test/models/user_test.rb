require "test_helper"

class UserTest < ActiveSupport::TestCase
  include MessageQuotaHelper

  test "fixture password digests use the cheapest bcrypt cost" do
    assert_equal(BCrypt::Engine::MIN_COST, BCrypt::Password.new(users(:one).password_digest).cost)
  end

  test "requires a name" do
    user = User.new(name: "", email_address: "new@example.com", password: "password")
    assert_not user.valid?
    assert user.errors[:name].any?
  end

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "initials come from the first two name words" do
    assert_equal "AL", users(:one).initials
  end

  test "accepts a png avatar" do
    user = users(:one)
    user.avatar.attach(io: File.open(file_fixture("avatar.png")), filename: "avatar.png", content_type: "image/png")
    assert user.valid?
  end

  test "rejects a non-image avatar" do
    user = users(:one)
    user.avatar.attach(io: StringIO.new("plain text"), filename: "notes.txt", content_type: "text/plain")
    assert_not user.valid?
  end

  test "processes a thumb avatar variant with the vips processor" do
    user = users(:one)
    user.avatar.attach(io: File.open(file_fixture("avatar.png")), filename: "avatar.png", content_type: "image/png")

    variant = user.avatar.variant(:thumb).processed
    image = Vips::Image.new_from_buffer(variant.download, "")

    assert_equal 48, image.width
    assert_equal 48, image.height
  end

  test "the daily quota counts only today's own messages" do
    user = users(:one)
    chat = user.chats.create!(model: "gpt-4o-mini")
    seed_messages(chat, 3)
    seed_messages(chat, 2, role: "assistant")
    seed_messages(chat, 4, created_at: 1.day.ago)

    assert_equal User::DAILY_MESSAGE_LIMIT - 3, user.messages_remaining_today
  end

  test "the daily quota counts every chat, support included" do
    user = users(:one)
    seed_messages(user.chats.create!(model: "gpt-4o-mini"), 2)
    seed_messages(user.chats.create!(support: true), 3)

    assert_equal User::DAILY_MESSAGE_LIMIT - 5, user.messages_remaining_today
  end

  test "the daily quota never goes negative" do
    user = users(:one)
    seed_messages(user.chats.create!(model: "gpt-4o-mini"), User::DAILY_MESSAGE_LIMIT + 1)

    assert_equal 0, user.messages_remaining_today
  end

  test "the daily quota reads its own index instead of every person's messages" do
    sql = users(:one).messages_sent_today.select("COUNT(*)").to_sql
    plan = ActiveRecord::Base.connection.select_rows("EXPLAIN QUERY PLAN #{sql}").map(&:last)

    assert plan.any? { |step| step.include?("index_messages_on_chat_id_and_role_and_created_at") }, plan.inspect
  end

  test "changing the password in the profile context requires the current password" do
    user = users(:one)
    user.password = "newpassword123"

    assert_not user.valid?(:profile)
    assert_equal 1, user.errors[:password_challenge].size
  end

  test "changing the password outside the profile context needs no challenge" do
    user = users(:one)
    user.password = "newpassword123"

    assert user.valid?
  end

  test "the profile context accepts the matching current password" do
    user = users(:one)
    user.password = "newpassword123"
    user.password_challenge = "password"

    assert user.valid?(:profile)
  end

  test "the profile context rejects a wrong current password" do
    user = users(:one)
    user.password = "newpassword123"
    user.password_challenge = "wrong"

    assert_not user.valid?(:profile)
    assert user.errors[:password_challenge].any?
  end

  test "changing the email requires the current password" do
    user = users(:one)
    user.unconfirmed_email = "ada-new@example.com"

    assert_not user.valid?(:profile)
    assert user.errors[:password_challenge].any?
  end

  test "clearing the pending email also requires the current password" do
    user = users(:one)
    user.update!(unconfirmed_email: "ada-new@example.com")
    user.unconfirmed_email = nil

    assert_not user.valid?(:profile)
    assert user.errors[:password_challenge].any?
  end

  test "the profile context refuses a new email another account already owns" do
    user = users(:one)
    user.unconfirmed_email = users(:two).email_address.upcase
    user.password_challenge = "password"

    assert_not user.valid?(:profile)
    assert user.errors.added?(:unconfirmed_email, :taken)
  end

  test "the profile context accepts a new email nobody owns" do
    user = users(:one)
    user.unconfirmed_email = "ada-new@example.com"
    user.password_challenge = "password"

    assert user.valid?(:profile)
  end

  test "an untouched profile needs no challenge" do
    user = users(:one)
    user.name = "Ada King"

    assert user.valid?(:profile)
  end

  test "normalizes unconfirmed_email and blanks it to nil" do
    user = users(:one)

    user.unconfirmed_email = " ADA-NEW@EXAMPLE.COM "
    assert_equal "ada-new@example.com", user.unconfirmed_email

    user.unconfirmed_email = "  "
    assert_nil user.unconfirmed_email
  end

  test "rejects a malformed unconfirmed_email" do
    user = users(:one)
    user.unconfirmed_email = "not-an-email"

    assert_not user.valid?
    assert user.errors[:unconfirmed_email].any?
  end

  test "confirm_email_change moves the pending email over" do
    user = users(:one)
    user.update!(unconfirmed_email: "ada-new@example.com")

    assert user.confirm_email_change
    assert_equal "ada-new@example.com", user.reload.email_address
    assert_nil user.unconfirmed_email
  end

  test "confirm_email_change fails when the address was taken meanwhile" do
    user = users(:one)
    user.update!(unconfirmed_email: "taken@example.com")
    users(:two).update!(email_address: "taken@example.com")

    assert_not user.confirm_email_change
    assert_equal "ada@example.com", user.reload.email_address
  end

  test "the email change token dies when the pending email changes" do
    user = users(:one)
    user.update!(unconfirmed_email: "first@example.com")
    token = user.generate_token_for(:email_change)

    user.update!(unconfirmed_email: "second@example.com")

    assert_nil User.find_by_token_for(:email_change, token)
  end

  test "destroying a user erases the usage it owns" do
    user = users(:one)
    usage = user.ruby_llm_usages.create!(operation: "embedding", provider: "openai", model: "text-embedding-3-small", status: "succeeded")

    user.destroy!

    assert_not RubyLLM::ActiveRecord::Usage.exists?(usage.id)
  end

  test "purge_unconfirmed destroys unconfirmed accounts past the retention window" do
    old_unconfirmed = unconfirmed_user_at((User::UNCONFIRMED_RETENTION + 1.day).ago)

    assert_difference "User.count", -1 do
      User.purge_unconfirmed
    end
    assert_not User.exists?(old_unconfirmed.id)
  end

  test "purge_unconfirmed keeps unconfirmed accounts inside the retention window" do
    recent_unconfirmed = unconfirmed_user_at(1.day.ago)

    assert_no_difference "User.count" do
      User.purge_unconfirmed
    end
    assert User.exists?(recent_unconfirmed.id)
  end

  test "purge_unconfirmed keeps old confirmed accounts" do
    old_confirmed = unconfirmed_user_at((User::UNCONFIRMED_RETENTION + 1.day).ago)
    old_confirmed.confirm!

    assert_no_difference "User.count" do
      User.purge_unconfirmed
    end
    assert User.exists?(old_confirmed.id)
  end

  test "finish_requested_deletions erases accounts whose queued erasure never finished" do
    stuck = users(:one)
    stuck.update!(deletion_requested_at: (User::DELETION_SWEEP_DELAY + 1.minute).ago)

    User.finish_requested_deletions

    assert_not User.exists?(stuck.id)
  end

  test "finish_requested_deletions leaves a fresh request to its job" do
    fresh = users(:one)
    fresh.update!(deletion_requested_at: 1.minute.ago)

    User.finish_requested_deletions

    assert User.exists?(fresh.id)
  end

  private

  def unconfirmed_user_at(created_at)
    user = User.create!(name: "Unconf", email_address: "unconfirmed-#{SecureRandom.hex(4)}@example.com", password: "password1234")
    user.update_column(:created_at, created_at)
    user
  end
end
