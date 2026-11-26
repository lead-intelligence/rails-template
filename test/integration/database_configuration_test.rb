require "test_helper"
require "puma/configuration"

class DatabaseConfigurationTest < ActiveSupport::TestCase
  # Solid Queue runs as threads inside Puma (config/puma.rb), so one process
  # holds Puma's request threads, Action Cable's workers and the job threads,
  # plus Solid Queue's own: its poller, its heartbeats, its dispatcher and its
  # scheduler, which take queue connections while the job threads run.
  SOLID_QUEUE_OWN_THREADS = 4

  test "every thread of the one process gets a connection without waiting" do
    puma = Puma::Configuration.new({}, config_files: [ Rails.root.join("config/puma.rb").to_s ]).tap(&:clamp)
    job_threads = YAML.load(ERB.new(Rails.root.join("config/queue.yml").read).result, aliases: true)
      .dig("production", "workers").sum { |worker| worker["threads"] }
    needed = puma.options[:max_threads] + ActionCable.server.config.worker_pool_size + job_threads

    %w[development production].each do |environment|
      primary = ActiveRecord::Base.configurations.configs_for(env_name: environment, name: "primary")
      queue = ActiveRecord::Base.configurations.configs_for(env_name: environment, name: "queue")

      assert_operator primary.max_connections, :>=, needed,
        "In #{environment}, request threads, Action Cable's workers and job threads share one process and one pool."
      assert_operator queue.max_connections, :>=, needed + SOLID_QUEUE_OWN_THREADS,
        "In #{environment}, Solid Queue's own threads take queue connections too."
    end
  end
end
