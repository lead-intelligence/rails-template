require "test_helper"
require "rake"

class AtelierTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("atelier:owner")
    @task = Rake::Task["atelier:owner"]
    @task.reenable
    Rake::Task["atelier:people"].reenable
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

  private

  def with_env(values)
    before = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    before.each { |key, value| ENV[key] = value }
  end
end
