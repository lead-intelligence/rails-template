require "test_helper"

class ImageBuildTest < ActiveSupport::TestCase
  DOCKERFILE = Rails.root.join("Dockerfile")

  test "the runtime image installs the file command that checks an upload's real type" do
    packages = DOCKERFILE.read[/FROM .* AS base.*?apt-get install[^\n]*/m]

    assert_match(/ file /, packages,
      "spoofing_protection runs `file` on every upload; the slim base image lacks it, so production would reject every photo")
  end
end
