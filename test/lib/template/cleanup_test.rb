require "test_helper"
require "tmpdir"

class Template::CleanupTest < ActiveSupport::TestCase
  include GitIdentityHelper

  setup { stub_git_identity }
  teardown { restore_git_identity }

  test "removes the tooling that only serves the template" do
    in_fixture_tree do |dir|
      Template::Cleanup.new(root: dir, app_name: "Demo").run

      Template::Cleanup::REMOVED_PATHS.each do |path|
        assert_not File.exist?(File.join(dir, path)), "expected #{path} to be removed"
      end
    end
  end

  test "keeps the application's own code" do
    in_fixture_tree do |dir|
      Template::Cleanup.new(root: dir, app_name: "Demo").run

      assert File.exist?(File.join(dir, "docs", "design-substrate.md"))
      assert File.exist?(File.join(dir, "bin", "setup"))
    end
  end

  test "drops the smoke step from the continuous integration script" do
    in_fixture_tree do |dir|
      Template::Cleanup.new(root: dir, app_name: "Demo").run

      ci = File.read(File.join(dir, "config", "ci.rb"))
      assert_not_includes ci, "Smoke:"
      assert_includes ci, "Tests: Rails"
    end
  end

  test "rewrites the readme so it describes an application rather than a template" do
    in_fixture_tree do |dir|
      Template::Cleanup.new(root: dir, app_name: "Demo").run

      readme = File.read(File.join(dir, "README.md"))
      assert_includes readme, "Demo is a Rails application built from"
      assert_not_includes readme, "starter template"
      assert_not_includes readme, "smoke_app"
      assert_not_includes readme, "SMOKE_PORT"
      assert_not_includes readme, "and a `bin/smoke-rename` step"
      assert_not_includes readme, "## Updating this template"
      assert_not_includes readme, "## Starting a new app"
      assert_not_includes readme, "bin/spawn my_app"
      assert_includes readme, "## Testing"
      assert_includes readme, "## Porting template improvements"
    end
  end

  test "rewrites CLAUDE.md so it maps an application rather than a template" do
    in_fixture_tree do |dir|
      Template::Cleanup.new(root: dir, app_name: "Demo").run

      claude = File.read(File.join(dir, "CLAUDE.md"))
      assert_includes claude, "Demo is a Rails application"
      assert_not_includes claude, "Rails starter template"
      assert_not_includes claude, "bin/rename"
      assert_not_includes claude, "bin/smoke-rename"
      assert_not_includes claude, "bin/spawn"
      assert_not_includes claude, "bin/children"
      assert_includes claude, "seven steps"
      assert_includes claude, "- `bin/setup`"
      assert_includes claude, "## Subsystem map"
    end
  end

  test "this template's own readme still carries the anchors the cleanup depends on" do
    readme = Rails.root.join("README.md").read

    assert_match Template::Cleanup::INTRO_SECTION, readme
    assert_match Template::Cleanup::TEMPLATE_SECTION, readme
    assert_match Template::Cleanup::STARTING_SECTION, readme
    assert_includes readme, Template::Cleanup::CI_CLAUSE
    Template::Cleanup::SMOKE_MARKERS.each { |marker| assert_includes readme, marker }
  end

  test "this template's own CLAUDE.md still carries the anchors the cleanup depends on" do
    claude = Rails.root.join("CLAUDE.md").read

    assert_match Template::Cleanup::CLAUDE_INTRO, claude
    assert_match Template::Cleanup::CLAUDE_COMMANDS, claude
    assert_includes claude, Template::Cleanup::CLAUDE_CI_CLAUSE
    assert_includes claude, Template::Cleanup::CLAUDE_STEP_COUNT
    assert_equal 4, claude.scan(Template::Cleanup::CLAUDE_COMMANDS).size,
      "expected exactly the four template-only command bullets (bin/rename, bin/smoke-rename, bin/spawn, bin/children); " \
      "renaming one without updating CLAUDE_COMMANDS would leave a dead command bullet in every child app"
  end

  test "drops the smoke step from the bin/ci bullet even when an earlier line mentions bin/smoke-rename first" do
    in_fixture_tree do |dir|
      claude_path = File.join(dir, "CLAUDE.md")
      content = File.read(claude_path)
      decoy = "- `bin/setup` — install and prepare everything, then runs `bin/rails test`, `bin/smoke-rename`, and boots the app.\n"
      content = content.sub("## Commands\n", "## Commands\n#{decoy}")
      File.write(claude_path, content)

      Template::Cleanup.new(root: dir, app_name: "Demo").run

      claude = File.read(claude_path)
      ci_bullet = claude.lines.find { |line| line.include?("bin/ci") }
      assert_includes claude, "seven steps"
      assert_not_includes ci_bullet, "bin/smoke-rename",
        "the bin/ci bullet must drop its own smoke-rename mention, not an earlier decoy line"
    end
  end

  test "this template's own ci script still carries the step the cleanup removes" do
    assert_match Template::Cleanup::CI_STEP, Rails.root.join("config/ci.rb").read
  end

  test "cuts the git link to the template so a stray push cannot reach it" do
    in_fixture_tree do |dir|
      system("git", "-C", dir, "init", "--quiet")
      system("git", "-C", dir, "remote", "add", "template", "git@github.com:bruno-costanzo/rails-template.git")
      system("git", "-C", dir, "remote", "add", "origin", "git@github.com:someone/demo.git")

      Template::Cleanup.new(root: dir, app_name: "Demo").run

      remotes = `git -C #{dir} remote`.split
      assert_not_includes remotes, "template"
      assert_includes remotes, "origin", "an app's own remote must survive"
    end
  end

  test "cuts the git link to the template from a path that holds a space or shell syntax" do
    in_fixture_tree("my app; $(touch pwned) ") do |dir|
      system("git", "-C", dir, "init", "--quiet", exception: true)
      system("git", "-C", dir, "remote", "add", "template", "git@github.com:bruno-costanzo/rails-template.git", exception: true)

      Template::Cleanup.new(root: dir, app_name: "Demo").run

      assert_empty IO.popen([ "git", "-C", dir, "remote" ], &:read).split
      assert_not File.exist?("pwned")
    end
  end

  test "stops when git cannot read the remotes of a tree that claims a repository" do
    in_fixture_tree do |dir|
      FileUtils.mkdir(File.join(dir, ".git"))

      assert_raises(RuntimeError) { Template::Cleanup.new(root: dir, app_name: "Demo").run }
    end
  end

  test "a tree with no git repository is left alone" do
    in_fixture_tree do |dir|
      assert_nothing_raised { Template::Cleanup.new(root: dir, app_name: "Demo").run }
    end
  end

  private

  def in_fixture_tree(name = "app")
    Dir.mktmpdir do |tmp|
      dir = File.join(tmp, name)
      FileUtils.mkdir(dir)
      %w[bin lib/template test/lib/template docs/superpowers config].each { |path| FileUtils.mkdir_p(File.join(dir, path)) }
      FileUtils.touch(File.join(dir, "bin", "rename"))
      FileUtils.touch(File.join(dir, "bin", "smoke-rename"))
      FileUtils.touch(File.join(dir, "bin", "spawn"))
      FileUtils.touch(File.join(dir, "bin", "children"))
      FileUtils.touch(File.join(dir, "children.yml"))
      FileUtils.touch(File.join(dir, "bin", "setup"))
      FileUtils.touch(File.join(dir, "lib", "template", "renamer.rb"))
      FileUtils.touch(File.join(dir, "test", "lib", "template", "renamer_test.rb"))
      FileUtils.touch(File.join(dir, "docs", "superpowers", "plan.md"))
      File.write(File.join(dir, "docs", "design-substrate.md"), "tokens")
      File.write(File.join(dir, "config", "ci.rb"), <<~RUBY)
        CI.run do
          step "Tests: Rails", "bin/rails test"
          step "Smoke: renamed app boots and serves", "bin/smoke-rename"
        end
      RUBY
      File.write(File.join(dir, "CLAUDE.md"), <<~MARKDOWN)
        # Demo

        Rails starter template. New apps are born from it with `bin/rename <new_app_name>`.

        ## Commands
        - `bin/setup` — install and prepare everything.
        - `bin/ci` — configured in `config/ci.rb` with eight steps: rubocop, `bin/rails test`, `bin/smoke-rename`.
        - `bin/rename <name>` — turn the template into a new app.
          It also deletes `lib/template/` and `test/lib/template/`.
        - `bin/smoke-rename` — export, rename, boot, serve.
          **Gotcha:** it exports tracked changes only.
        - `bin/spawn <name>` — clone into `../<name>`.
        - `bin/children` — report each child's pending commits.

        ## Subsystem map
        - **Auth** — sign-in blocks until confirmed. → `auth.md`
      MARKDOWN
      File.write(File.join(dir, "README.md"), <<~MARKDOWN)
        # Demo

        ## What is this

        Demo is a Rails starter template you clone and rename.

        ## Starting a new app

        From inside this template's own directory: `bin/spawn my_app`.

        ## Testing

        Run `bin/ci`: rubocop, `bin/rails test`, and a `bin/smoke-rename` step.

        That last step runs `bin/rename smoke_app` on a copy.

        Override the port with `SMOKE_PORT` if it is taken.

        Tests never hit the network.

        ## Updating this template

        Bump the Rails constraint and re-run everything.

        ## Porting template improvements

        Cherry-pick from the template remote.
      MARKDOWN
      yield dir
    end
  end
end
