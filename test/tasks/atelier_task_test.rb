require "test_helper"
require "rake"

class AtelierTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("atelier:owner")
    @task = Rake::Task["atelier:owner"]
    @task.reenable
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

  private

  def with_env(values)
    before = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    before.each { |key, value| ENV[key] = value }
  end
end
