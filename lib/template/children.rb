require "open3"

module Template
  class Children
    def initialize(root:)
      @root = Pathname.new(root)
      @path = @root.join("children.yml")
    end

    def register(name, path:, sha:)
      data = load
      data[name] = { "path" => path, "born_from" => sha, "synced_to" => sha }
      save(data)
    end

    def mark_synced(name, sha = head)
      data = load
      entry = data.fetch(name)
      entry["synced_to"] = sha
      save(data)
    end

    def report
      load.map { |name, entry| report_line(name, entry) }.join("\n\n")
    end

    private

    def report_line(name, entry)
      child_path = @root.join(entry["path"])
      return "#{name} (#{entry["path"]}): missing" unless child_path.directory?
      return "#{name} (#{entry["path"]}): present, unknown sync point #{entry["synced_to"]}" unless commit?(entry["synced_to"])

      pending = pending_commits(entry["synced_to"])
      return "#{name} (#{entry["path"]}): present, up to date" if pending.empty?

      oldest_sha = pending_shas(entry["synced_to"]).first

      lines = [ "#{name} (#{entry["path"]}): present, #{pending.size} pending commit(s)" ]
      lines += pending.map { |commit| "  #{commit}" }
      lines << "  git -C #{entry["path"]} fetch #{@root} main && git -C #{entry["path"]} cherry-pick #{oldest_sha}"
      lines << "  bin/children synced #{name} #{oldest_sha}"
      lines.join("\n")
    end

    def pending_commits(synced_to)
      run_git("log", "--reverse", "--oneline", "#{synced_to}..HEAD").lines.map(&:strip)
    end

    def pending_shas(synced_to)
      run_git("rev-list", "--reverse", "#{synced_to}..HEAD").lines.map(&:strip)
    end

    def commit?(sha)
      system("git", "-C", @root.to_s, "cat-file", "-e", "#{sha}^{commit}", out: File::NULL, err: File::NULL)
    end

    def head
      run_git("rev-parse", "HEAD").strip
    end

    def run_git(*args)
      stdout, stderr, status = Open3.capture3("git", "-C", @root.to_s, *args)
      raise "git #{args.join(" ")} failed: #{stderr}" unless status.success?

      stdout
    end

    def load
      return {} unless @path.exist?

      YAML.load(@path.read) || {}
    end

    def save(data)
      @path.write(data.to_yaml)
    end
  end
end
