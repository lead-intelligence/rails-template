require "test_helper"

class ModulePreloadsTest < ActionDispatch::IntegrationTest
  test "pages do not preload the rich text editor" do
    get root_url

    assert_response :success
    assert_select "link[rel=modulepreload][href*=lexxy]", count: 0
    assert_select "script[type=importmap]", text: /"lexxy":/
  end

  test "pages do not preload modules nothing on them imports" do
    get root_url

    assert_response :success
    assert_select "link[rel=modulepreload][href*=activestorage]", count: 0
    assert_select "link[rel=modulepreload][href*=railspress]", count: 0
    assert_select "script[type=importmap]", text: %r{"railspress/controllers/dropzone_controller":}
  end

  test "pages do not load the reactive template runtime they never use" do
    get root_url

    assert_response :success
    assert_select "link[rel=modulepreload][href*=reactionview]", count: 0
    assert_no_match(/import "reactionview"/, Rails.root.join("app/javascript/application.js").read)
  end
end
