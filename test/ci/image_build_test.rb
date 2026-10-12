require "test_helper"

class ImageBuildTest < ActiveSupport::TestCase
  DOCKERFILE = Rails.root.join("Dockerfile")
  DEPLOY = Rails.root.join("config/deploy.yml")
  AGENT = "--mount=type=ssh".freeze

  test "the image build forwards the ssh agent to the bundler that fetches the private mobile gem" do
    install = DOCKERFILE.readlines.find { |line| line.include?("bundle install") }

    assert_includes install, AGENT,
      "charco_mobile lives in a private repository reached over SSH, so a build without the agent never resolves it"
  end

  test "kamal hands its builder the ssh agent the image build asks for" do
    assert_equal "default=$SSH_AUTH_SOCK", YAML.safe_load(DEPLOY.read).dig("builder", "ssh"),
      "the mount is inert unless the build is invoked with the agent forwarded"
  end

  test "the runtime image installs the file command that checks an upload's real type" do
    packages = DOCKERFILE.read[/FROM .* AS base.*?apt-get install[^\n]*/m]

    assert_match(/ file /, packages,
      "spoofing_protection runs `file` on every upload; the slim base image lacks it, so production would reject every photo")
  end
end
