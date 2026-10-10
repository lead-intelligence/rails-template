require "test_helper"

class ModulePreloadsTest < ActionDispatch::IntegrationTest
  test "pages do not preload the rich text editor" do
    get root_url

    assert_response :success
    assert_select "link[rel=modulepreload][href*=lexxy]", count: 0
    assert_select "script[type=importmap]", text: /"lexxy":/
  end
end
