require "test_helper"

class BackupAccessoryTest < ActiveSupport::TestCase
  test "the backup image is pinned to a release" do
    image = YAML.safe_load(Rails.root.join("config/deploy.yml").read).dig("accessories", "backup", "image")

    assert_match(/:\d+\.\d+\.\d+\z/, image,
      "the container holds the restic and storage keys and mounts every file; a moving tag pulls whatever ships next on any reboot")
  end
end
