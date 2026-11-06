require "test_helper"

class ThemePaletteTest < ActiveSupport::TestCase
  RAW_PALETTE = /\b(?:bg|text|border|divide|outline|ring|from|to)-(?:slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-\d{2,3}\b/

  test "views color through the theme, never through Tailwind's fixed palette" do
    offenders = Rails.root.glob("app/views/**/*.erb").filter_map do |path|
      path.relative_path_from(Rails.root).to_s if path.read.match?(RAW_PALETTE)
    end

    assert_empty offenders, "a fixed palette class keeps its light-theme color in the dark theme; use the DaisyUI tokens"
  end
end
