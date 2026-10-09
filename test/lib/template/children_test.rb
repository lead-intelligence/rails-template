require "test_helper"
require "tmpdir"

class Template::ChildrenTest < ActiveSupport::TestCase
  include GitIdentityHelper

  setup { stub_git_identity }
  teardown { restore_git_identity }

  test "every git command a test spawns runs with background maintenance off" do
    in_git_root do |root|
      assert_equal "0", `git -C #{root} config gc.auto`.strip
      assert_equal "false", `git -C #{root} config maintenance.auto`.strip
    end
  end

  test "register writes an entry with born_from equal to synced_to" do
    in_tmp_root do |root|
      Template::Children.new(root: root).register("demo", path: "../demo", sha: "abc123")

      data = YAML.load(root.join("children.yml").read)
      assert_equal "abc123", data["demo"]["born_from"]
      assert_equal data["demo"]["born_from"], data["demo"]["synced_to"]
      assert_equal "../demo", data["demo"]["path"]
    end
  end

  test "report marks a child whose directory is missing" do
    in_tmp_root do |root|
      children = Template::Children.new(root: root)
      children.register("demo", path: "../demo", sha: "abc123")

      assert_includes children.report, "missing"
    end
  end

  test "report lists pending commits with ready cherry-pick commands" do
    in_git_root do |root|
      children = Template::Children.new(root: root)
      first_sha = `git -C #{root} rev-parse HEAD`.strip
      FileUtils.mkdir_p(root.parent.join("demo"))
      children.register("demo", path: "../demo", sha: first_sha)

      File.write(root.join("second.txt"), "second")
      system("git", "-C", root.to_s, "add", "-A", exception: true)
      system("git", "-C", root.to_s, "commit", "--quiet", "-m", "Second commit", exception: true)
      second_sha = `git -C #{root} rev-parse HEAD`.strip

      report = children.report
      assert_includes report, "1 pending commit(s)"
      assert_includes report, "cherry-pick #{second_sha}"
      assert_includes report, "bin/children synced demo #{second_sha}"
    end
  end

  test "report targets the oldest pending commit, not the newest" do
    in_git_root do |root|
      children = Template::Children.new(root: root)
      first_sha = `git -C #{root} rev-parse HEAD`.strip
      FileUtils.mkdir_p(root.parent.join("demo"))
      children.register("demo", path: "../demo", sha: first_sha)

      shas = %w[second third fourth].map do |name|
        File.write(root.join("#{name}.txt"), name)
        system("git", "-C", root.to_s, "add", "-A", exception: true)
        system("git", "-C", root.to_s, "commit", "--quiet", "-m", "#{name.capitalize} commit", exception: true)
        `git -C #{root} rev-parse HEAD`.strip
      end
      oldest_sha = shas.first

      report = children.report
      assert_includes report, "3 pending commit(s)"
      assert_includes report, "cherry-pick #{oldest_sha}"
      assert_includes report, "bin/children synced demo #{oldest_sha}"

      children.mark_synced("demo", oldest_sha)
      assert_includes children.report, "2 pending commit(s)"
    end
  end

  test "report flags a child whose sync point the template no longer has, and still reports the rest" do
    in_git_root do |root|
      children = Template::Children.new(root: root)
      FileUtils.mkdir_p(root.parent.join("demo"))
      FileUtils.mkdir_p(root.parent.join("other"))
      children.register("demo", path: "../demo", sha: "0" * 40)
      children.register("other", path: "../other", sha: `git -C #{root} rev-parse HEAD`.strip)

      report = children.report
      assert_includes report, "demo (../demo): present, unknown sync point #{"0" * 40}"
      assert_includes report, "other (../other): present, up to date"
    end
  end

  test "register into an empty children.yml" do
    in_tmp_root do |root|
      root.join("children.yml").write("")

      Template::Children.new(root: root).register("demo", path: "../demo", sha: "abc123")

      assert_equal "abc123", YAML.load(root.join("children.yml").read)["demo"]["synced_to"]
    end
  end

  test "report says up to date and present for a synced child" do
    in_git_root do |root|
      children = Template::Children.new(root: root)
      sha = `git -C #{root} rev-parse HEAD`.strip
      FileUtils.mkdir_p(root.parent.join("demo"))
      children.register("demo", path: "../demo", sha: sha)

      report = children.report
      assert_includes report, "present"
      assert_includes report, "up to date"
    end
  end

  test "mark_synced with an explicit sha updates the entry" do
    in_tmp_root do |root|
      children = Template::Children.new(root: root)
      children.register("demo", path: "../demo", sha: "abc123")

      children.mark_synced("demo", "def456")

      data = YAML.load(root.join("children.yml").read)
      assert_equal "def456", data["demo"]["synced_to"]
    end
  end

  test "mark_synced without a sha defaults to the template's HEAD" do
    in_git_root do |root|
      children = Template::Children.new(root: root)
      children.register("demo", path: "../demo", sha: "0000000")

      children.mark_synced("demo")

      head = `git -C #{root} rev-parse HEAD`.strip
      data = YAML.load(root.join("children.yml").read)
      assert_equal head, data["demo"]["synced_to"]
    end
  end

  test "mark_synced without a sha raises outside a git repository" do
    in_tmp_root do |root|
      children = Template::Children.new(root: root)
      children.register("demo", path: "../demo", sha: "abc123")

      assert_raises(RuntimeError) { children.mark_synced("demo") }
    end
  end

  test "mark_synced raises for an unregistered name" do
    in_tmp_root do |root|
      assert_raises(KeyError) { Template::Children.new(root: root).mark_synced("ghost", "abc123") }
    end
  end

  private

  def in_tmp_root
    Dir.mktmpdir do |tmp|
      root = Pathname.new(tmp).join("root")
      FileUtils.mkdir_p(root)
      yield root
    end
  end

  def in_git_root
    in_tmp_root do |root|
      system("git", "-C", root.to_s, "init", "--quiet", exception: true)
      File.write(root.join("first.txt"), "first")
      system("git", "-C", root.to_s, "add", "-A", exception: true)
      system("git", "-C", root.to_s, "commit", "--quiet", "-m", "First commit", exception: true)
      yield root
    end
  end
end
