require "test_helper"

class BackupConfigurationTest < ActiveSupport::TestCase
  CONFIG = YAML.safe_load(Rails.root.join("config/kamal-backup.yml").read)
  STORAGE = "/rails/storage".freeze

  test "backs up the databases that hold data a restore needs" do
    assert_equal %w[primary queue], CONFIG["databases"].map { it["name"] },
      "cache and cable hold only disposable data, and db:prepare recreates both on boot after a restore"
  end

  test "the file snapshot never copies a live SQLite file or the logs" do
    storage = CONFIG["paths"].find { it["path"] == STORAGE }

    assert storage, "Active Storage files live under #{STORAGE}"
    assert_equal %W[#{STORAGE}/*.sqlite3 #{STORAGE}/*.sqlite3-wal #{STORAGE}/*.sqlite3-shm #{STORAGE}/logs].sort, storage["exclude"].sort,
      "a raw copy of a live database is not a consistent backup, and the logs take up to half a gigabyte"
  end
end
