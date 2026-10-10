require "test_helper"
require "open3"

class ProductionLoggerTest < ActiveSupport::TestCase
  test "production runs a tagged block once, so a job is enqueued and performed once" do
    script = <<~RUBY
      require "./config/application"
      load "config/environments/production.rb"
      logger = Rails.application.config.logger
      runs = 0
      logger.tagged("probe") { runs += 1 }
      print [ runs, logger.broadcasts.size ].join(",")
    RUBY

    output, status = Open3.capture2e({ "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1" },
      RbConfig.ruby, "-e", script, chdir: Rails.root.to_s)

    assert status.success?, output
    runs, sinks = output.lines.last.split(",").map(&:to_i)
    assert_equal 2, sinks, "Production logs to STDOUT and to the file onlylogs reads."
    assert_equal 1, runs,
      "Active Job wraps enqueue and perform in `logger.tagged { }`. Run twice, every job is enqueued twice and runs twice."
  end
end
