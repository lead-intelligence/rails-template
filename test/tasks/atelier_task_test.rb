require "test_helper"
require "rake"

class AtelierTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("atelier:owner")
    @task = Rake::Task["atelier:owner"]
    @task.reenable
    Rake::Task["atelier:people"].reenable
    Rake::Task["atelier:access"].reenable
  end

  test "makes the owner's account, confirmed, that signs in with the password" do
    with_env("EMAIL" => "owner@atelier.test", "PASSWORD" => "a-long-password") { @task.invoke }

    user = User.find_by!(email_address: "owner@atelier.test")
    assert user.confirmed_at
    assert user.authenticate("a-long-password")
  end

  test "exits 3 and changes nothing when the account exists" do
    user = User.create!(name: "Ana", email_address: "owner@atelier.test", password: "the-old-password",
      confirmed_at: Time.current)

    error = assert_raises(SystemExit) do
      with_env("EMAIL" => "owner@atelier.test", "PASSWORD" => "a-long-password") { @task.invoke }
    end

    assert_equal 3, error.status
    assert user.reload.authenticate("the-old-password")
    assert_equal "Ana", user.name
  end

  test "people lists who a tester can sign in as, the owner first, one email<TAB>label per line" do
    User.update_all(confirmed_at: nil)
    owner = User.create!(name: "Owner", email_address: "owner@atelier.test", password: "a-long-password", confirmed_at: Time.current)
    User.demo_account!("seller", name: "Sam")
    User.demo_account!("cashier", name: "Cleo")

    I18n.backend.store_translations(I18n.default_locale, atelier: { people: { seller: "Vendedor" } })
    output, = capture_io { Rake::Task["atelier:people"].invoke }

    assert_equal [
      "#{owner.email_address}\t#{I18n.t("atelier.people.owner")}",
      "seller@#{User::DEMO_DOMAIN}\tVendedor",
      "cashier@#{User::DEMO_DOMAIN}\tCleo"
    ], output.lines(chomp: true)
  ensure
    I18n.reload!
  end

  test "access makes a confirmed account and prints only the link to choose its password" do
    output, = capture_io do
      with_env("EMAIL" => "Ana@Atelier.test", "NAME" => "Ana", "ROLE" => "", "ADMIN" => "") { Rake::Task["atelier:access"].invoke }
    end

    user = User.find_by!(email_address: "ana@atelier.test")
    assert_equal "Ana", user.name
    assert user.confirmed?
    assert_equal 1, output.lines.size
    assert_match %r{\Ahttp://example.com/passwords/[^/]+/edit\n\z}, output
    assert_equal user, User.find_by_password_reset_token(output.split("/")[-2])
  end

  test "access to an account that exists keeps its name and password, and confirms it" do
    user = User.create!(name: "Ana", email_address: "ana@atelier.test", password: "the-old-password")

    output, = capture_io { with_env("EMAIL" => "ana@atelier.test", "NAME" => nil) { Rake::Task["atelier:access"].invoke } }

    user.reload
    assert_equal "Ana", user.name
    assert user.confirmed?
    assert user.authenticate("the-old-password")
    assert_equal user, User.find_by_password_reset_token(output.split("/")[-2])
  end

  test "access sets the role and admin of an app whose users have them" do
    User.connection.add_column :users, :role, :string
    User.connection.add_column :users, :admin, :boolean, default: false, null: false
    User.reset_column_information

    capture_io { with_env("EMAIL" => "ana@atelier.test", "NAME" => "Ana", "ROLE" => "seller", "ADMIN" => "true") { Rake::Task["atelier:access"].invoke } }

    user = User.find_by!(email_address: "ana@atelier.test")
    assert_equal [ "seller", true ], [ user.role, user.admin ]
  ensure
    User.reset_column_information
  end

  test "access refuses a column this app's users do not have, and makes nothing" do
    error = nil
    _, said = capture_io do
      error = assert_raises(SystemExit) { with_env("EMAIL" => "ana@atelier.test", "NAME" => "Ana", "ROLE" => "seller") { Rake::Task["atelier:access"].invoke } }
    end

    assert_equal 1, error.status
    assert_equal "this app's users have no role\n", said
    assert_not User.exists?(email_address: "ana@atelier.test")
  end

  test "access says what the account lacks, and makes nothing" do
    error = nil
    _, said = capture_io do
      error = assert_raises(SystemExit) { with_env("EMAIL" => "ana@atelier.test", "NAME" => nil) { Rake::Task["atelier:access"].invoke } }
    end

    assert_equal 1, error.status
    assert_match I18n.t("errors.messages.blank"), said
    assert_not User.exists?(email_address: "ana@atelier.test")
  end

  private

  def with_env(values)
    before = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    before.each { |key, value| ENV[key] = value }
  end
end
