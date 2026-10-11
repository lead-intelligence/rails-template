require "test_helper"
require "open3"

class TemplateEngineTest < ActiveSupport::TestCase
  test "a malformed template fails the test suite" do
    assert ReActionView.config.intercept_erb
    assert_equal :raise, ReActionView.config.validation_mode
  end

  test "development shows template errors in an overlay" do
    assert_equal [ "true", "overlay", "true" ], boot_and_report("development")
  end

  test "production renders through Herb without the development overlay" do
    assert_equal [ "true", "none", "false" ], boot_and_report("production"),
      "The overlay middleware buffers every HTML response, and its report would show template paths to visitors."
  end

  private
    def boot_and_report(environment)
      script = <<~RUBY
        require "./config/application"
        Rails.application.class.initializer(:skip_eager_load, after: :load_environment_config) { config.eager_load = false }
        Rails.application.initialize!
        config = ReActionView.config
        herb = Rails.application.middleware.map(&:inspect).include?("Herb::Engine::Runtime::Middleware")
        print [ config.intercept_erb, config.validation_mode, herb ].join(",")
      RUBY

      output, status = Open3.capture2e({ "RAILS_ENV" => environment, "SECRET_KEY_BASE_DUMMY" => "1" },
        RbConfig.ruby, "-e", script, chdir: Rails.root.to_s)

      assert status.success?, output
      output.lines.last.split(",")
    end
end
