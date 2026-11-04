require "test_helper"

class DeployWorkflowTest < ActiveSupport::TestCase
  WORKFLOW = Rails.root.join(".github/workflows/deploy.yml")
  SSH_AGENT = "webfactory/ssh-agent".freeze
  SETUP_RUBY = "ruby/setup-ruby".freeze
  TEMPLATE_REPOSITORY = "lead-intelligence/rails-template".freeze

  test "the keys are loaded before Bundler installs the gems" do
    assert_operator step_index(SSH_AGENT), :<, step_index(SETUP_RUBY),
      "bundler-cache installs the gems inside the Ruby step, and charco_mobile is a private git gem"
  end

  test "GitHub is trusted before Bundler installs the gems" do
    assert_operator steps.index { |step| step["run"].to_s.include?("ssh-keyscan -t ed25519 github.com") },
      :<, step_index(SETUP_RUBY)
  end

  test "the template itself never deploys" do
    assert_includes job["if"], "github.repository != '#{TEMPLATE_REPOSITORY}'",
      "the template has no server key and a placeholder domain, so every deploy run fails"
    assert_includes job["if"], "github.event.workflow_run.conclusion == 'success'"
  end

  private

  def job
    YAML.safe_load(WORKFLOW.read).dig("jobs", "deploy")
  end

  def steps
    job["steps"]
  end

  def step_index(action)
    steps.index { |step| step["uses"].to_s.start_with?(action) }
  end
end
