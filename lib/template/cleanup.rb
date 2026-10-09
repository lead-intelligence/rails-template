require "open3"

module Template
  class Cleanup
    REMOVED_PATHS = %w[bin/rename bin/smoke-rename bin/spawn bin/children children.yml lib/template test/lib/template docs/superpowers].freeze
    SMOKE_MARKERS = %w[smoke_app SMOKE_PORT].freeze
    CI_STEP = /^\s*step "Smoke:[^\n]*\n/
    CI_CLAUSE = ", and a `bin/smoke-rename` step"
    INTRO_SECTION = /^## What is this\n\n.*?(?=\n## )/m
    TEMPLATE_SECTION = /^## Updating this template\n\n.*?\n\n(?=## )/m
    STARTING_SECTION = /^## Starting a new app\n\n.*?\n\n(?=## )/m
    CLAUDE_INTRO = /^Rails starter template\.[^\n]*\n/
    CLAUDE_COMMANDS = /^- `bin\/(?:rename|smoke-rename|spawn|children)(?![\w-])[^\n]*\n(?:[ \t]+[^\n]*\n)*/
    CLAUDE_CI_CLAUSE = ", `bin/smoke-rename`"
    CLAUDE_STEP_COUNT = "eight steps"
    CHILD_STEP_COUNT = "seven steps"
    CLAUDE_CI_BULLET_LINE = /^.*#{Regexp.escape(CLAUDE_STEP_COUNT)}.*\n/
    TEMPLATE_URL = "https://github.com/bruno-costanzo/rails-template"
    TEMPLATE_SLUG = "rails-template"

    def initialize(root:, app_name:)
      @root = Pathname.new(root)
      @app_name = app_name
    end

    def run
      REMOVED_PATHS.each { |path| FileUtils.rm_rf(@root.join(path)) }
      detach_from_template
      rewrite("config/ci.rb") { |content| content.gsub(CI_STEP, "") }
      rewrite("README.md") { |content| clean_readme(content) }
      rewrite("CLAUDE.md") { |content| clean_claude(content) }
    end

    private

    def detach_from_template
      return unless @root.join(".git").directory?

      template_remotes.each do |remote|
        system("git", "-C", @root.to_s, "remote", "remove", remote, out: File::NULL, err: File::NULL)
      end
    end

    def template_remotes
      stdout, stderr, status = Open3.capture3("git", "-C", @root.to_s, "remote", "-v")
      raise "git remote -v failed: #{stderr}" unless status.success?

      stdout.lines.filter_map { |line| line.split.first if line.include?(TEMPLATE_SLUG) }.uniq
    end

    def rewrite(relative_path)
      path = @root.join(relative_path)
      path.write(yield(path.read))
    end

    def clean_readme(content)
      content = content.sub(INTRO_SECTION, "## What is this\n\n#{intro}\n")
      content = content.sub(CI_CLAUSE, "")
      content = content.sub(TEMPLATE_SECTION, "")
      content = content.sub(STARTING_SECTION, "")
      content.split("\n\n").reject { |paragraph| describes_removed_tooling?(paragraph) }.join("\n\n")
    end

    def clean_claude(content)
      content = content.sub(CLAUDE_INTRO, claude_intro)
      content = content.sub(CLAUDE_CI_BULLET_LINE) { |line| line.sub(CLAUDE_CI_CLAUSE, "").sub(CLAUDE_STEP_COUNT, CHILD_STEP_COUNT) }
      content.gsub(CLAUDE_COMMANDS, "")
    end

    def claude_intro
      "#{@app_name} is a Rails application. This file is the map for agents; each subsystem's detail lives in `docs/architecture/`.\n"
    end

    def describes_removed_tooling?(paragraph)
      SMOKE_MARKERS.any? { |marker| paragraph.include?(marker) }
    end

    def intro
      "#{@app_name} is a Rails application built from the [rails-template](#{TEMPLATE_URL}) starter. Everything described below already ships with it."
    end
  end
end
