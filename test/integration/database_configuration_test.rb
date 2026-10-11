require "test_helper"
require "puma/configuration"

class DatabaseConfigurationTest < ActiveSupport::TestCase
  test "every request thread and every Action Cable worker of a process gets a connection without waiting" do
    puma = Puma::Configuration.new({}, config_files: [ Rails.root.join("config/puma.rb").to_s ]).tap(&:clamp)
    needed = puma.options[:max_threads] + ActionCable.server.config.worker_pool_size

    %w[development production].each do |environment|
      primary = ActiveRecord::Base.configurations.configs_for(env_name: environment, name: "primary")

      assert_operator primary.max_connections, :>=, needed,
        "In #{environment}, Puma's request threads and Action Cable's workers share one process and one pool."
    end
  end
end
