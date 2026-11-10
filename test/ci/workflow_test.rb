require "test_helper"

class CiWorkflowTest < ActiveSupport::TestCase
  WORKFLOW = Rails.root.join(".github/workflows/ci.yml")

  test "the workflow can be started by hand, the only way to retry a run after a secret is registered" do
    assert_includes triggers.keys, "workflow_dispatch",
      "without it a repository whose secret was just set can only be retried through an empty commit"
  end

  test "the workflow token can only read the repository" do
    assert_equal({ "contents" => "read" }, workflow["permissions"],
      "the job runs pull request code; a changed organization default would hand it a write token")
  end

  test "no step condition reads the secrets context, which GitHub does not expose there" do
    conditions = steps.filter_map { |step| step["if"] }

    assert_empty conditions.grep(/secrets\./),
      "a condition on secrets.* is always false, so the step it guards never runs"
  end

  test "a private app runs on our own runners, a public repository and a run by hand on GitHub's" do
    assert_equal "${{ inputs.runner || (github.event.repository.private && 'ci-amd64' || 'ubuntu-latest') }}", job["runs-on"],
      "GitHub's runners spend a private repository's minutes; ours would run a stranger's pull request to a public one"
    assert_equal %w[ci-amd64 ubuntu-latest], triggers.dig("workflow_dispatch", "inputs", "runner", "options"),
      "with no ci-amd64 runner up, a run started by hand on GitHub's runners is the fallback"
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
