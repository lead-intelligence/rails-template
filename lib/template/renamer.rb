module Template
  class Renamer
    SKIP_DIRS = %w[.git docs log node_modules storage tmp vendor].freeze
    OLD_MODULE = "CharcoTemplate".freeze
    OLD_SNAKE = "charco_template".freeze
    OLD_DASHED = "charco-template".freeze
    OLD_TITLE = "Charco Template".freeze

    def initialize(root:, new_name:)
      @root = Pathname.new(root)
      @new_snake = new_name.underscore
    end

    def run
      text_files.each { |path| rewrite(path) }
    end

    private

    def new_module = @new_snake.camelize

    def new_dashed = @new_snake.dasherize

    def new_title = @new_snake.titleize

    def text_files
      Dir.glob("**/*", File::FNM_DOTMATCH, base: @root)
        .map { |relative| @root.join(relative).to_s }
        .select { |path| File.file?(path) && !skip?(path) && text?(path) }
    end

    def skip?(path)
      relative = Pathname.new(path).relative_path_from(@root).to_s
      relative.end_with?(".mjs") || SKIP_DIRS.any? { |dir| relative == dir || relative.start_with?("#{dir}/") }
    end

    def text?(path)
      !File.binread(path, 8192).to_s.include?("\x00")
    end

    def rewrite(path)
      original = File.read(path)
      updated = original.gsub(OLD_MODULE, new_module).gsub(OLD_SNAKE, @new_snake).gsub(OLD_DASHED, new_dashed).gsub(OLD_TITLE, new_title)
      File.write(path, updated) if updated != original
    end
  end
end
