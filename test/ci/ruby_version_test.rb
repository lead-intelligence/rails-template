require "test_helper"

class RubyVersionTest < ActiveSupport::TestCase
  RUBY = Rails.root.join(".ruby-version").read.strip.delete_prefix("ruby-")

  test "the production image builds on the Ruby in .ruby-version" do
    assert_equal RUBY, Rails.root.join("Dockerfile").read[/^ARG RUBY_VERSION=(.+)$/, 1],
      "a deploy that passes no build args would run another Ruby than the one the tests ran"
  end

  test "CI runs on the Ruby in .ruby-version" do
    container = YAML.safe_load(Rails.root.join(".github/workflows/ci.yml").read).dig("jobs", "ci", "container", "image")

    assert_equal "ghcr.io/lead-intelligence/rails-ci:#{RUBY}", container,
      "CI would pass on another Ruby than the one development and production run; " \
      ".github/workflows/ci-image.yml tags the image with the Ruby in .ruby-version"
  end
end
