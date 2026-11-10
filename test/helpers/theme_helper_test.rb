require "test_helper"

class ThemeHelperTest < ActionView::TestCase
  test "follows the system without a stored choice" do
    assert_equal "system", theme_preference
  end

  test "returns the stored choice" do
    cookies[:theme] = "dark"

    assert_equal "dark", theme_preference
  end

  test "ignores a theme it does not ship" do
    cookies[:theme] = "neon"

    assert_equal "system", theme_preference
  end
end
