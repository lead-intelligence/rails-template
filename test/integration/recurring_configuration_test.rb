require "test_helper"

class RecurringConfigurationTest < ActiveSupport::TestCase
  test "every production recurring command calls a class method that exists" do
    tasks = YAML.load(ERB.new(Rails.root.join("config/recurring.yml").read).result, aliases: true).fetch("production")

    tasks.each do |name, task|
      receiver, method = task.fetch("command")[/\A([A-Z][\w:]*)\.(\w+)/, 0].to_s.split(".")

      assert receiver && receiver.safe_constantize&.respond_to?(method),
        "#{name} runs #{task["command"].inspect}, which only fails once production runs it."
    end
  end
end
