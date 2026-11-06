require "test_helper"

class DeployWorkflowTest < ActiveSupport::TestCase
  WORKFLOW = Rails.root.join(".github/workflows/deploy.yml")
  TEMPLATE_REPOSITORY = "lead-intelligence/rails-template".freeze

  test "the template itself never deploys" do
    assert_includes jobs.dig("latest", "if"), "github.repository != '#{TEMPLATE_REPOSITORY}'",
      "the template has no server key and a placeholder domain, so every deploy run fails"
    assert_includes jobs.dig("latest", "if"), "github.event.workflow_run.conclusion == 'success'"
  end

  test "only the commit at the tip of main deploys" do
    assert_equal "latest", jobs.dig("deploy", "needs")
    assert_equal "needs.latest.outputs.current == 'true'", jobs.dig("deploy", "if"),
      "CI runs finish out of order, so an older commit could deploy after a newer one and roll production back"
  end

  test "Bundler installs the gems before the server key is loaded" do
    assert_operator step_index("ruby/setup-ruby"), :<, step_index("webfactory/ssh-agent"),
      "every gem's install code would otherwise run with root access to the server"
  end

  test "only a push to this repository's main deploys" do
    assert_includes jobs.dig("latest", "if"), "github.event.workflow_run.event == 'push'",
      "the branches filter matches a pull request's head branch, so a fork's branch named main would deploy"
    assert_includes jobs.dig("latest", "if"), "github.event.workflow_run.head_repository.full_name == github.repository"
  end

  test "the action that receives the server key is pinned to a commit" do
    assert_match(/\Awebfactory\/ssh-agent@\h{40}\z/, jobs.dig("deploy", "steps").find { |step| step["uses"].to_s.start_with?("webfactory/ssh-agent") }["uses"],
      "a tag can be moved to other code, and this action holds root access to the server")
  end

  private

  def jobs
    YAML.safe_load(WORKFLOW.read).fetch("jobs")
  end

  def step_index(action)
    jobs.dig("deploy", "steps").index { |step| step["uses"].to_s.start_with?(action) }
  end
end
