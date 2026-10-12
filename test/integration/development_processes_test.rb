require "test_helper"

class DevelopmentProcessesTest < ActiveSupport::TestCase
  test "development runs the job supervisor inside the web server, like production does" do
    puma = Rails.root.join("config/puma.rb").read

    assert_match(/plugin :solid_queue if .*RAILS_ENV.*development/, puma,
      "Development must run Solid Queue inside Puma. Otherwise `bin/rails server` serves pages while every " \
      "background job — chat replies, email, embeddings — piles up unprocessed and nothing says so.")
    assert_not_includes Rails.root.join("Procfile.dev").read, "bin/jobs",
      "With the supervisor inside Puma, a separate jobs process would run every job twice."
  end

  test "bin/dev runs the Herb dev server, which the dev tools connect to" do
    assert_includes Rails.root.join("Procfile.dev").read.lines.map(&:strip), "herb: bin/herb dev"
  end

  test "development broadcasts the way production does" do
    cable = YAML.load_file(Rails.root.join("config/cable.yml"), aliases: true)

    assert_equal cable.dig("production", "adapter"), cable.dig("development", "adapter"),
      "Development should use production's cable adapter so a broadcast from a console or a job behaves the same."
  end
end
