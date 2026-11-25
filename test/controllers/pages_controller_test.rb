require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  test "home is public and renders meta title" do
    get root_url
    assert_response :success
    assert_select "title", "#{I18n.t('pages.home.meta_title')} | #{Rails.application.class.module_parent_name}"
  end

  test "home sends a signed-in user to the signed-in home" do
    sign_in_as users(:one)
    get root_url
    assert_redirected_to chats_url
  end
end
