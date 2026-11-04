require "test_helper"

# charco_mobile lives in a private repository. Bundler reads it over HTTPS with
# one read-only token, the organization's CHARCO_MOBILE_TOKEN secret, handed to
# Bundler as BUNDLE_GITHUB__COM. Dependabot reads it with the same token, from
# the organization's Dependabot secrets, so it can open the
# updates Peronix merges.
class PrivateGemTest < ActiveSupport::TestCase
  CREDENTIAL = "BUNDLE_GITHUB__COM".freeze
  FROM_SECRET = "x-access-token:${{ secrets.CHARCO_MOBILE_TOKEN }}".freeze

  test "the gem comes from GitHub over HTTPS, the only way Dependabot reads a private gem" do
    assert_match(/^gem "charco_mobile", github: "lead-intelligence\/charco_mobile"/, read("Gemfile"))
    assert_includes read("Gemfile.lock"), "remote: https://github.com/lead-intelligence/charco_mobile.git"
  end

  test "CI hands Bundler the token" do
    assert_equal FROM_SECRET, workflow("ci").dig("jobs", "ci", "env", CREDENTIAL),
      "bin/ci installs the gems again in its rename smoke, so the whole job needs it"
  end

  test "the deploy hands the token to Bundler and to the image build" do
    assert_equal FROM_SECRET, workflow("deploy").dig("jobs", "deploy", "env", CREDENTIAL)
    assert_includes YAML.safe_load(read("config/deploy.yml")).dig("builder", "secrets"), CREDENTIAL
    assert_includes read(".kamal/secrets"), "#{CREDENTIAL}=$#{CREDENTIAL}"
  end

  test "the image build reads the token as a build secret, which never stays in the image" do
    install = read("Dockerfile").lines.find { |line| line.include?("bundle install") }

    assert_includes install, "--mount=type=secret,id=#{CREDENTIAL},env=#{CREDENTIAL}"
  end

  test "Dependabot reads the gem with the same token, since a public repository gets no organization grant" do
    config = YAML.safe_load(read(".github/dependabot.yml"))
    bundler = config["updates"].find { |update| update["package-ecosystem"] == "bundler" }

    assert_equal({ "type" => "git", "url" => "https://github.com", "username" => "x-access-token",
                   "password" => "${{secrets.CHARCO_MOBILE_TOKEN}}" }, config.dig("registries", "charco-mobile"))
    assert_equal [ "charco-mobile" ], bundler["registries"]
  end

  test "nothing reaches the gem over SSH any more" do
    files = %w[Gemfile Dockerfile config/deploy.yml .github/workflows/ci.yml .github/workflows/deploy.yml]

    files.each { |file| assert_no_match(/CHARCO_MOBILE_DEPLOY_KEY|type=ssh|git@github\.com/, read(file), file) }
  end

  private

  def read(path)
    Rails.root.join(path).read
  end

  def workflow(name)
    YAML.safe_load(read(".github/workflows/#{name}.yml"))
  end
end
