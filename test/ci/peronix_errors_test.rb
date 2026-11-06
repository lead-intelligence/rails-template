require "test_helper"

# Each app tells Peronix of its new errors (app/models/peronix_errors.rb). The
# deploy hands the app Peronix's address, an organization variable, and the
# app's own token, a repository secret Peronix prints for it.
class PeronixErrorsDeployTest < ActiveSupport::TestCase
  NAMES = { "PERONIX_ERRORS_URL" => "${{ vars.PERONIX_ERRORS_URL }}",
            "PERONIX_ERRORS_TOKEN" => "${{ secrets.PERONIX_ERRORS_TOKEN }}" }.freeze

  test "the deploy hands the app Peronix's address and the app's token" do
    env = YAML.safe_load(Rails.root.join(".github/workflows/deploy.yml").read).dig("jobs", "deploy", "env")
    app = YAML.safe_load(Rails.root.join("config/deploy.yml").read).dig("env", "secret")
    secrets = Rails.root.join(".kamal/secrets").read

    NAMES.each do |name, source|
      assert_equal source, env[name]
      assert_includes app, name
      assert_includes secrets.lines.map(&:strip), "#{name}=$#{name}"
    end
  end
end
