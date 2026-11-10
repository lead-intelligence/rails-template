require "application_system_test_case"

class ThemeTest < ApplicationSystemTestCase
  test "follows the system until a theme is chosen" do
    visit root_url

    assert_selector "input.theme-controller[value='system']:checked", visible: :all
  end

  test "remembers the chosen theme across page loads" do
    visit root_url

    choose_theme :dark
    refresh

    assert_selector "input.theme-controller[value='dark']:checked", visible: :all
    assert_equal "dark", page.evaluate_script("getComputedStyle(document.documentElement).colorScheme")
  end
end
