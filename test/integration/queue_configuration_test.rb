require "test_helper"

class QueueConfigurationTest < ActiveSupport::TestCase
  test "an idle worker picks up a new job within a tenth of a second" do
    config = YAML.load(ERB.new(Rails.root.join("config/queue.yml").read).result, aliases: true)

    config.dig("production", "workers").each do |worker|
      assert_operator worker.fetch("polling_interval"), :<=, 0.1,
        "An idle worker sleeps this long between polls, so every chat reply waits up to that long to start."
    end
  end
end
