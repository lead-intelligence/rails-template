require "open3"

module Template
  class Spawner
    class AlreadyExists < StandardError; end

    DEPLOY_KEY_SECRET = "CHARCO_MOBILE_DEPLOY_KEY".freeze
    DEPLOY_KEY_PATH = "CHARCO_MOBILE_DEPLOY_KEY_PATH".freeze

    def initialize(root:, name:, github: false)
      Renamer.validate_name!(name)
      @root = Pathname.new(root)
      @name = name
      @github = github
      @dest = @root.parent.join(name)
    end

    def run
      raise AlreadyExists, "#{@dest} already exists" if @dest.exist?

      give_birth
      @github ? create_github_repo : print_github_command
    end

    private

    def give_birth
      clone
      detach_from_template
      bundle
      rename
      commit
      register
    rescue StandardError
      FileUtils.rm_rf(@dest)
      raise
    end

    def clone
      system("git", "clone", "--quiet", @root.to_s, @dest.to_s, exception: true)
    end

    def detach_from_template
      system("git", "-C", @dest.to_s, "remote", "remove", "origin", exception: true)
    end

    def bundle
      return unless @dest.join("Gemfile").exist?

      Bundler.with_unbundled_env do
        system("bundle", "install", chdir: @dest.to_s, exception: true)
      end
    end

    def rename
      Bundler.with_unbundled_env do
        system("bin/rename", @name, chdir: @dest.to_s, exception: true)
      end
    end

    def commit
      system("git", "-C", @dest.to_s, "add", "-A", exception: true)
      system("git", "-C", @dest.to_s, "commit", "--quiet", "-m", "Rename template into #{@name}", exception: true)
    end

    def register
      stdout, stderr, status = Open3.capture3("git", "-C", @root.to_s, "rev-parse", "HEAD")
      raise "git rev-parse HEAD failed: #{stderr}" unless status.success?

      Children.new(root: @root).register(@name, path: "../#{@name}", sha: stdout.strip)
    end

    def create_github_repo
      system("gh", "repo", "create", @name, "--private", "--source=.", "--remote=origin", "--push", chdir: @dest.to_s, exception: true)
      register_deploy_key
    end

    def print_github_command
      puts "gh repo create #{@name} --private --source=. --remote=origin --push"
      puts deploy_key_command
    end

    def register_deploy_key
      key = deploy_key
      return puts(deploy_key_command) if key.nil?

      system("gh", "secret", "set", DEPLOY_KEY_SECRET, chdir: @dest.to_s, in: key.to_s, exception: true)
    end

    def deploy_key
      path = ENV[DEPLOY_KEY_PATH].to_s
      return if path.empty?

      key = Pathname.new(File.expand_path(path))
      key.exist? ? key : nil
    end

    def deploy_key_command
      "gh secret set #{DEPLOY_KEY_SECRET} --repo #{@name} < <the charco_mobile deploy key>"
    end
  end
end
