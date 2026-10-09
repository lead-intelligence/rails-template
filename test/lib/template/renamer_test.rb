require "test_helper"
require "tmpdir"

class Template::RenamerTest < ActiveSupport::TestCase
  include GitIdentityHelper

  setup do
    stub_git_identity
    @target = "#{Rails.application.class.module_parent_name.underscore}_renamed"
  end

  teardown { restore_git_identity }

  test "rewrites module, snake, dashed and title-case names in text files" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "application.rb"), "module CharcoTemplate\nend\n")
      File.write(File.join(dir, "deploy.yml"), "service: charco_template\nhost: charco-template.example.com\n")
      File.write(File.join(dir, "layout.html.erb"), "<meta name=\"application-name\" content=\"Charco Template\">\n")
      FileUtils.mkdir(File.join(dir, "tmp"))
      File.write(File.join(dir, "tmp", "skipped.rb"), "CharcoTemplate")
      Template::Renamer.new(root: dir, new_name: @target).run
      assert_includes File.read(File.join(dir, "application.rb")), "module #{@target.camelize}"
      assert_includes File.read(File.join(dir, "deploy.yml")), "service: #{@target}"
      assert_includes File.read(File.join(dir, "deploy.yml")), "#{@target.dasherize}.example.com"
      assert_includes File.read(File.join(dir, "layout.html.erb")), @target.titleize
      assert_includes File.read(File.join(dir, "tmp", "skipped.rb")), "CharcoTemplate"
    end
  end

  test "renames a tree whose path holds glob characters" do
    Dir.mktmpdir do |tmp|
      root = File.join(tmp, "apps [old]")
      FileUtils.mkdir_p(root)
      path = File.join(root, "application.rb")
      File.write(path, "module CharcoTemplate\nend\n")

      Template::Renamer.new(root: root, new_name: @target).run

      assert_includes File.read(path), "module #{@target.camelize}"
    end
  end

  test "in a git checkout, rewrites only the files git tracks" do
    Dir.mktmpdir do |root|
      tracked = File.join(root, "application.rb")
      untracked = File.join(root, ".claude", "worktrees", "x", "file.rb")
      File.write(tracked, "module CharcoTemplate\nend\n")
      FileUtils.mkdir_p(File.dirname(untracked))
      File.write(untracked, "module CharcoTemplate\nend\n")
      system("git", "-C", root, "init", "--quiet", exception: true)
      system("git", "-C", root, "add", "application.rb", exception: true)

      Template::Renamer.new(root: root, new_name: @target).run

      assert_includes File.read(tracked), "module #{@target.camelize}"
      assert_equal "module CharcoTemplate\nend\n", File.read(untracked)
    end
  end

  test "refuses to guess which files to rename when git cannot list them" do
    Dir.mktmpdir do |root|
      File.write(File.join(root, ".git"), "not a gitdir")

      assert_raises(RuntimeError) { Template::Renamer.new(root: root, new_name: @target).run }
    end
  end

  test "refuses a name that cannot become a Ruby module before touching any file" do
    [ "2fast", "my app", "my.app", "mi_app_ñ", "my__app", "my_app_", "../escape", "/abs", "" ].each do |name|
      Dir.mktmpdir do |root|
        path = File.join(root, "application.rb")
        File.write(path, "module CharcoTemplate\nend\n")

        assert_raises(Template::Renamer::InvalidName, name.inspect) { Template::Renamer.new(root: root, new_name: name).run }
        assert_equal "module CharcoTemplate\nend\n", File.read(path)
      end
    end
  end

  test "accepts a name in snake, dashed or module case" do
    %w[my_app my-app MyApp meal4two api_v2].each do |name|
      assert_nil Template::Renamer.validate_name!(name), name
    end
  end

  test "leaves docs directory untouched to preserve historical spec content" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir(File.join(dir, "docs"))
      path = File.join(dir, "docs", "spec.md")
      File.write(path, "CharcoTemplate")

      Template::Renamer.new(root: dir, new_name: @target).run

      assert_equal "CharcoTemplate", File.read(path)
    end
  end

  test "treats empty files as text and leaves them untouched without raising" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".gitkeep")
      FileUtils.touch(path)

      Template::Renamer.new(root: dir, new_name: @target).run

      assert_equal "", File.read(path)
    end
  end

  test "leaves files without a template reference untouched" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "unrelated.txt")
      File.write(path, "hello world")
      mtime_before = File.mtime(path)

      Template::Renamer.new(root: dir, new_name: @target).run

      assert_equal "hello world", File.read(path)
      assert_equal mtime_before, File.mtime(path)
    end
  end
end
