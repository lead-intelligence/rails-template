module ThemeHelper
  THEMES = { "light" => "sun", "system" => "monitor", "dark" => "moon" }.freeze

  def theme_preference
    THEMES.key?(cookies[:theme]) ? cookies[:theme] : "system"
  end
end
