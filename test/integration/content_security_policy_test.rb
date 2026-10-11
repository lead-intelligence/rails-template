require "test_helper"

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
end
