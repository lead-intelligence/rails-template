module GitIdentityHelper
  GIT_ENV_KEYS = %w[
    GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_CONFIG_GLOBAL
    GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_1
  ].freeze

  def stub_git_identity
    @original_git_env = GIT_ENV_KEYS.to_h { |key| [ key, ENV[key] ] }
    ENV["GIT_AUTHOR_NAME"] = "Test"
    ENV["GIT_AUTHOR_EMAIL"] = "test@example.com"
    ENV["GIT_COMMITTER_NAME"] = "Test"
    ENV["GIT_COMMITTER_EMAIL"] = "test@example.com"
    ENV["GIT_CONFIG_GLOBAL"] = "/dev/null"

    # Every git child process spawned by a test (its own fixture setup, and any git commands
    # Template::Spawner runs against that fixture) inherits these, so background gc/maintenance
    # never fires and can't race the test's own reads of .git/objects.
    ENV["GIT_CONFIG_COUNT"] = "2"
    ENV["GIT_CONFIG_KEY_0"] = "gc.auto"
    ENV["GIT_CONFIG_VALUE_0"] = "0"
    ENV["GIT_CONFIG_KEY_1"] = "maintenance.auto"
    ENV["GIT_CONFIG_VALUE_1"] = "false"
  end

  def restore_git_identity
    @original_git_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
