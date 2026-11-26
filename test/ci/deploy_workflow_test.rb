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

  test "the deploy installs only the gems Kamal needs" do
    assert_equal "deploy", jobs.dig("deploy", "env", "BUNDLE_ONLY"),
      "every gem's install code runs in the job that later holds the server key, and a process it leaves behind outlives the step"
    assert_equal [ "kamal" ], Bundler.definition.dependencies.select { |dependency| dependency.groups == [ :deploy ] }.map(&:name)
  end

  test "only a push to this repository's main deploys" do
    assert_includes jobs.dig("latest", "if"), "github.event.workflow_run.event == 'push'",
      "the branches filter matches a pull request's head branch, so a fork's branch named main would deploy"
    assert_includes jobs.dig("latest", "if"), "github.event.workflow_run.head_repository.full_name == github.repository"
  end

  test "every action the deploy runs is pinned to a commit" do
    jobs.dig("deploy", "steps").filter_map { |step| step["uses"] }.each do |action|
      assert_match(/@\h{40}\z/, action, "a tag can be moved to other code, and this job runs on the production server")
    end
  end

  test "every job runs on the production server's runner" do
    assert_equal({ "latest" => "deploy", "deploy" => "deploy" }, jobs.transform_values { |job| job["runs-on"] },
      "GitHub's runners spend the organization's minutes; the deploy runner group takes only this workflow from main")
  end

  test "the credentials key leaves the runner after every deploy, failed or not" do
    last = jobs.dig("deploy", "steps").last

    assert_equal "always()", last["if"]
    assert_equal "rm -f config/master.key .kamal/secrets-common", last["run"],
      "the server's runner keeps its workspace after the job, unlike GitHub's"
  end

  test "each APP_ secret reaches the app's container under its own name" do
    deploy = jobs.dig("deploy", "steps").find { |step| step["name"] == "Deploy" }

    assert_equal "${{ toJSON(secrets) }}", deploy.dig("env", "SECRETS")
    assert_includes deploy["run"], 'name.start_with?("APP_")'
    assert_equal [ "RAILS_MASTER_KEY", "RESEND_API_KEY", "MAIL_FROM" ],
      kamal_secrets("RESEND_API_KEY MAIL_FROM"), "Kamal hands the container only the names config/deploy.yml lists"
    assert_equal [ "RAILS_MASTER_KEY" ], kamal_secrets(nil), "a deploy by hand has no ATELIER_ENV"
  end

  private

  def jobs
    YAML.safe_load(WORKFLOW.read).fetch("jobs")
  end

  def kamal_secrets(atelier_env)
    before = ENV["ATELIER_ENV"]
    ENV["ATELIER_ENV"] = atelier_env
    YAML.safe_load(ERB.new(Rails.root.join("config/deploy.yml").read).result).dig("env", "secret")
  ensure
    ENV["ATELIER_ENV"] = before
  end
end
