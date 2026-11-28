require "test_helper"

class CiWorkflowTest < ActiveSupport::TestCase
  WORKFLOW = Rails.root.join(".github/workflows/ci.yml")

  test "the workflow can be started by hand, the only way to retry a run after a secret is registered" do
    assert_includes triggers.keys, "workflow_dispatch",
      "without it a repository whose secret was just set can only be retried through an empty commit"
  end

  test "the workflow token can only read the repository" do
    assert_equal({ "contents" => "read", "packages" => "read", "checks" => "read" }, workflow["permissions"],
      "the job runs pull request code; a changed organization default would hand it a write token")
  end

  test "no step condition reads the secrets context, which GitHub does not expose there" do
    conditions = steps.filter_map { |step| step["if"] }

    assert_empty conditions.grep(/secrets\./),
      "a condition on secrets.* is always false, so the step it guards never runs"
  end

  test "a private app runs on our own runners, a public repository and a run by hand on GitHub's" do
    assert_equal "${{ inputs.runner || (github.event.repository.private && 'ci-linux' || 'ubuntu-latest') }}", job["runs-on"],
      "GitHub's runners spend a private repository's minutes; ours would run a stranger's pull request to a public one"
    assert_equal %w[ci-linux ubuntu-latest], triggers.dig("workflow_dispatch", "inputs", "runner", "options"),
      "with no ci-linux runner up, a run started by hand on GitHub's runners is the fallback"
  end

  test "only a pull request into main runs CI: an epic's stories go into its branch, and nothing waits for them" do
    assert_equal({ "branches" => %w[main] }, triggers["pull_request"],
      "a story's pull request ran the whole CI next to its epic's, for nothing, and held a runner")
  end

  test "a merge whose code its pull request already tested ends green with no second run" do
    skip_step = steps.find { |step| step["id"] == "tested" }

    assert skip_step, "the merge into main ran bin/ci again on the code its pull request had passed"
    assert_equal "github.event_name == 'push'", skip_step["if"]
    assert_equal 2, steps.first.dig("with", "fetch-depth"), "the merge's second parent is its pull request's head"
    gated = steps.select { |step| step["name"].in?([ "Install gems", "Run quality gate" ]) }
    assert_equal [ "steps.tested.outputs.done != 'true'" ] * 2, gated.map { |step| step["if"] }
  end

  test "the quality gate runs the tests that failed once more, alone, before it fails" do
    gate = steps.find { |step| step["name"] == "Run quality gate" }

    assert_includes gate["run"], "bin/rerun-failed-tests tmp/ci.log",
      "a flaky system test made GitHub run the whole CI again, then cost a build"
    assert_equal "bash", gate["shell"]
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
