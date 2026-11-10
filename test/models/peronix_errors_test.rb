require "test_helper"

class PeronixErrorsTest < ActiveSupport::TestCase
  setup do
    @original = ENV.values_at("PERONIX_ERRORS_URL", "PERONIX_ERRORS_TOKEN")
    @peronix = Rails.configuration.x.peronix
    ENV["PERONIX_ERRORS_URL"] = "https://env.example/errors"
    ENV["PERONIX_ERRORS_TOKEN"] = "env-token"
  end

  teardown do
    ENV["PERONIX_ERRORS_URL"], ENV["PERONIX_ERRORS_TOKEN"] = @original
    Rails.configuration.x.peronix = @peronix
  end

  test "the address and token Peronix writes into the credentials win over the environment" do
    Rails.configuration.x.peronix = { errors_url: "https://peronix.example/errors", errors_token: "credentials-token" }
    sent = stub_request(:post, "https://peronix.example/errors").with(headers: { "Authorization" => "Bearer credentials-token" })

    PeronixErrors.report({ id: 1 })

    assert_requested sent
  end

  test "without credentials the environment stands in" do
    Rails.configuration.x.peronix = nil
    sent = stub_request(:post, "https://env.example/errors").with(headers: { "Authorization" => "Bearer env-token" })

    PeronixErrors.report({ id: 1 })

    assert_requested sent
  end

  test "tests never read the credentials, so a peronix block in them reports nothing from a test" do
    assert_equal({}, Rails.configuration.x.peronix.to_h)
  end

  test "it is set up only with both an address and a token" do
    assert PeronixErrors.configured?

    ENV["PERONIX_ERRORS_URL"] = nil
    assert_not PeronixErrors.configured?

    ENV["PERONIX_ERRORS_URL"] = "https://env.example/errors"
    ENV["PERONIX_ERRORS_TOKEN"] = ""
    assert_not PeronixErrors.configured?
  end
end
