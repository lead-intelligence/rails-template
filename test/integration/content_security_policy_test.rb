require "test_helper"
require "open3"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "responses carry a nonce-based content security policy" do
    get new_session_url

    csp = response.headers["Content-Security-Policy"]
    assert csp.present?, "expected a Content-Security-Policy header"
    assert_match "default-src 'self'", csp
    assert_match "object-src 'none'", csp
    assert_match %r{\Ascript-src 'self' 'sha256-DmLQcd2u48I2hHTg60qKOUbXlfzfga1g8zGJmQ0JIvA=' 'nonce-[^']+'\z}, csp[/script-src [^;]+/],
      "Beyond the nonce, scripts allow only the RailsPress admin layout's inline `import \"railspress\"`."
  end

  test "development lets the dev tools reach the Herb dev server" do
    assert_equal "'self' ws://localhost:*", connect_src_in("development")
  end

  test "production connects only to its own origin" do
    assert_equal "'self'", connect_src_in("production")
  end

  private
    def connect_src_in(environment)
      script = <<~RUBY
        require "./config/application"
        Rails.application.class.initializer(:skip_eager_load, after: :load_environment_config) { config.eager_load = false }
        Rails.application.initialize!
        print Rails.application.config.content_security_policy.build(nil).split("; ").find { it.start_with?("connect-src ") }.delete_prefix("connect-src ")
      RUBY

      output, status = Open3.capture2e({ "RAILS_ENV" => environment, "SECRET_KEY_BASE_DUMMY" => "1" },
        RbConfig.ruby, "-e", script, chdir: Rails.root.to_s)

      assert status.success?, output
      output.lines.last
    end
end
