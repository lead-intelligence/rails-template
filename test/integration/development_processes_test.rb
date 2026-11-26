require "test_helper"
require "puma/configuration"

class DevelopmentProcessesTest < ActiveSupport::TestCase
  test "development runs the job supervisor inside the web server, like production does" do
    puma = Rails.root.join("config/puma.rb").read

    assert_match(/if .*SOLID_QUEUE_IN_PUMA.*RAILS_ENV.*"development"\n\s*plugin :solid_queue/, puma,
      "Development must run Solid Queue inside Puma. Otherwise `bin/rails server` serves pages while every " \
      "background job — chat replies, email, embeddings — piles up unprocessed and nothing says so.")
    assert_not_includes Rails.root.join("Procfile.dev").read, "bin/jobs",
      "With the supervisor inside Puma, a separate jobs process would run every job twice."
  end

  test "Solid Queue runs as threads inside Puma, so each app loads Rails once" do
    puma = with_env("SOLID_QUEUE_IN_PUMA" => "true") do
      Puma::Configuration.new({}, config_files: [ Rails.root.join("config/puma.rb").to_s ]).tap(&:clamp)
    end

    assert_equal :async, puma.options[:solid_queue_mode],
      "In fork mode the supervisor, worker, dispatcher and scheduler are four more copies of Rails, " \
      "about 500 MB per app on a server that runs several apps."
  end

  test "bin/dev runs the Herb dev server, which the dev tools connect to" do
    assert_includes Rails.root.join("Procfile.dev").read.lines.map(&:strip), "herb: bin/herb dev"
  end

  test "development broadcasts the way production does" do
    cable = YAML.load_file(Rails.root.join("config/cable.yml"), aliases: true)

    assert_equal cable.dig("production", "adapter"), cable.dig("development", "adapter"),
      "Development should use production's cable adapter so a broadcast from a console or a job behaves the same."
  end

  private
    def with_env(values)
      before = values.keys.to_h { |key| [ key, ENV[key] ] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      before.each { |key, value| ENV[key] = value }
    end
end
