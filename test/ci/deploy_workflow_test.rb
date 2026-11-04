require "test_helper"

class DeployWorkflowTest < ActiveSupport::TestCase
  WORKFLOW = Rails.root.join(".github/workflows/deploy.yml")
  TEMPLATE_REPOSITORY = "lead-intelligence/rails-template".freeze

  test "the template itself never deploys" do
    assert_includes job["if"], "github.repository != '#{TEMPLATE_REPOSITORY}'",
      "the template has no server key and a placeholder domain, so every deploy run fails"
    assert_includes job["if"], "github.event.workflow_run.conclusion == 'success'"
  end

  private

  def job
    YAML.safe_load(WORKFLOW.read).dig("jobs", "deploy")
  end
end
