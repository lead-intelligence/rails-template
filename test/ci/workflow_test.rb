require "test_helper"

class CiWorkflowTest < ActiveSupport::TestCase
  WORKFLOW = Rails.root.join(".github/workflows/ci.yml")

  test "the workflow can be started by hand, the only way to retry a run after a secret is registered" do
    assert_includes triggers.keys, "workflow_dispatch",
      "without it a repository whose secret was just set can only be retried through an empty commit"
  end

  test "no step condition reads the secrets context, which GitHub does not expose there" do
    conditions = steps.filter_map { |step| step["if"] }

    assert_empty conditions.grep(/secrets\./),
      "a condition on secrets.* is always false, so the step it guards never runs"
  end

  private

  def workflow
    @workflow ||= YAML.safe_load(WORKFLOW.read)
  end

  def triggers
    workflow[true]
  end

  def job
    workflow.dig("jobs", "ci")
  end

  def steps
    job["steps"]
  end
end
