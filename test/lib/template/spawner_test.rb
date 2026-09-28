require "test_helper"
require "tmpdir"

class Template::SpawnerTest < ActiveSupport::TestCase
  class RecordingSpawner < Template::Spawner
    def steps = @steps ||= []

    private

    def bundle = steps << "bundle"

    def rename
      steps << "rename"
      File.write(@dest.join("renamed-#{@name}"), "")
    end
  end

  include GitIdentityHelper

  setup { stub_git_identity }
  teardown { restore_git_identity }

  test "clones the template, renames the clone, and registers it as a child" do
    in_template do |root|
      Template::Spawner.new(root: root, name: "demo").run

      dest = root.parent.join("demo")
      assert File.directory?(dest)
      assert_equal "", `git -C #{dest} remote`.strip
      assert File.exist?(dest.join("renamed-demo"))

      log = `git -C #{dest} log --oneline`.lines
      assert_equal 2, log.size
      assert_includes log.first, "Rename template into demo"

      registry = YAML.load(root.join("children.yml").read)
      assert_equal "../demo", registry["demo"]["path"]
      assert_equal registry["demo"]["born_from"], registry["demo"]["synced_to"]
    end
  end

  test "register raises when the template is not a git repository" do
    Dir.mktmpdir do |tmp|
      root = Pathname.new(tmp).join("root")
      FileUtils.mkdir_p(root)
      spawner = Template::Spawner.new(root: root, name: "demo")

      assert_raises(RuntimeError) { spawner.send(:register) }
    end
  end

  test "refuses to spawn into an already existing directory" do
    in_template do |root|
      FileUtils.mkdir_p(root.parent.join("demo"))

      assert_raises(Template::Spawner::AlreadyExists) do
        Template::Spawner.new(root: root, name: "demo").run
      end
    end
  end

  test "prints the gh command instead of running it without --github" do
    in_template do |root|
      output, = capture_io { Template::Spawner.new(root: root, name: "demo").run }

      assert_includes output, "gh repo create demo --private --source=. --remote=origin --push"
    end
  end

  test "bundles the clone before renaming it, which is what materializes a git-sourced gem" do
    in_template do |root|
      spawner = RecordingSpawner.new(root: root, name: "demo")
      spawner.run

      assert_equal %w[bundle rename], spawner.steps,
        "the clone carries no local override, so the gem the lock names has to be fetched before bin/rename loads it"
    end
  end

  test "the bundle runs in the clone, against the clone's own Gemfile" do
    in_template do |root|
      File.write(root.join("Gemfile"), %(source "https://rubygems.org"\n))
      system("git", "-C", root.to_s, "add", "-A", exception: true)
      system("git", "-C", root.to_s, "commit", "--quiet", "-m", "Add a Gemfile", exception: true)

      Template::Spawner.new(root: root, name: "demo").run

      assert File.exist?(root.parent.join("demo", "Gemfile.lock"))
    end
  end

  test "a clone with no Gemfile is left alone" do
    in_template do |root|
      Template::Spawner.new(root: root, name: "demo").run

      assert_not File.exist?(root.parent.join("demo", "Gemfile.lock"))
    end
  end

  test "creates the GitHub repository when --github is passed" do
    in_template do |root|
      with_fake_gh do |calls|
        with_deploy_key(nil) { Template::Spawner.new(root: root, name: "demo", github: true).run }

        assert_includes File.read(calls), "repo create demo --private --source=. --remote=origin --push"
      end
    end
  end

  test "registers the mobile deploy key on the new repository so its first CI run can bundle" do
    in_template do |root|
      with_fake_gh do |calls|
        key = Pathname.new(calls).dirname.join("deploy_key")
        key.write("A PRIVATE KEY")

        with_deploy_key(key) { Template::Spawner.new(root: root, name: "demo", github: true).run }

        log = File.read(calls)
        assert_includes log, "secret set CHARCO_MOBILE_DEPLOY_KEY"
        assert_includes log, "A PRIVATE KEY"
        assert_not_includes log.lines.first, "A PRIVATE KEY"
      end
    end
  end

  test "prints how to register the deploy key when no key is at hand" do
    in_template do |root|
      with_fake_gh do |calls|
        output, = capture_io do
          with_deploy_key(nil) { Template::Spawner.new(root: root, name: "demo", github: true).run }
        end

        assert_includes output, "gh secret set CHARCO_MOBILE_DEPLOY_KEY"
        assert_not_includes File.read(calls), "secret set"
      end
    end
  end

  test "prints how to register the deploy key when the path no longer holds one" do
    in_template do |root|
      with_fake_gh do |calls|
        missing = Pathname.new(calls).dirname.join("gone")

        output, = capture_io do
          with_deploy_key(missing) { Template::Spawner.new(root: root, name: "demo", github: true).run }
        end

        assert_includes output, "gh secret set CHARCO_MOBILE_DEPLOY_KEY"
        assert_not_includes File.read(calls), "secret set"
      end
    end
  end

  private

  def with_deploy_key(path)
    original = ENV["CHARCO_MOBILE_DEPLOY_KEY_PATH"]
    ENV["CHARCO_MOBILE_DEPLOY_KEY_PATH"] = path&.to_s
    yield
  ensure
    ENV["CHARCO_MOBILE_DEPLOY_KEY_PATH"] = original
  end

  def in_template
    Dir.mktmpdir do |tmp|
      root = Pathname.new(tmp).join("template")
      FileUtils.mkdir_p(root.join("bin"))
      File.write(root.join("first.txt"), "first")
      File.write(root.join("bin", "rename"), <<~'RUBY')
        #!/usr/bin/env ruby
        name = ARGV[0]
        File.write(File.join(Dir.pwd, "renamed-#{name}"), "")
      RUBY
      FileUtils.chmod("+x", root.join("bin", "rename"))
      system("git", "-C", root.to_s, "init", "--quiet", exception: true)
      system("git", "-C", root.to_s, "add", "-A", exception: true)
      system("git", "-C", root.to_s, "commit", "--quiet", "-m", "Initial commit", exception: true)
      yield root
    end
  end

  def with_fake_gh
    Dir.mktmpdir do |bin|
      calls = File.join(bin, "calls.log")
      File.write(File.join(bin, "gh"), <<~BASH)
        #!/usr/bin/env bash
        echo "$@" >> #{calls}
        if [ "$1" = "secret" ]; then cat >> #{calls}; fi
      BASH
      FileUtils.chmod("+x", File.join(bin, "gh"))
      original_path = ENV["PATH"]
      ENV["PATH"] = "#{bin}:#{original_path}"
      begin
        yield calls
      ensure
        ENV["PATH"] = original_path
      end
    end
  end
end
