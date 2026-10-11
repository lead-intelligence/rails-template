require "test_helper"
require "open3"

class EagerLoadTest < ActiveSupport::TestCase
  test "the app eager loads against a database that has not been migrated yet" do
    Dir.mktmpdir do |dir|
      env = { "RAILS_ENV" => "test", "CI" => "1", "DATABASE_URL" => "sqlite3:#{dir}/empty.sqlite3" }

      output, status = Open3.capture2e(env, "bin/rails", "runner", "print Rails.application.config.eager_load", chdir: Rails.root.to_s)

      assert status.success?, output
      assert_equal "true", output.lines.last
    end
  end
end
