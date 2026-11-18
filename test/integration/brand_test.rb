require "test_helper"
require "action_view/testing/resolvers"

class BrandTest < ActionDispatch::IntegrationTest
  test "the app name comes from one locale key" do
    with_app_name("Brand Probe") do
      get root_path

      assert_select ".navbar a[href='#{root_path}']", text: /Brand Probe/
      assert_select "title", text: /Brand Probe/
      assert_select "meta[name='application-name'][content='Brand Probe']"

      get pwa_manifest_path(format: :json)

      assert_equal "Brand Probe", JSON.parse(response.body)["name"]
    end
  end

  test "the navbar draws the logo partial" do
    original = ApplicationController.view_paths
    ApplicationController.prepend_view_path(ActionView::FixtureResolver.new("shared/_logo.html.erb" => "<b id=\"logo-probe\"></b>"))

    get root_path

    assert_select ".navbar a[href='#{root_path}'] #logo-probe"
  ensure
    ApplicationController.view_paths = original
  end

  test "the default logo is an icon" do
    get root_path

    assert_select ".navbar a[href='#{root_path}'] svg"
  end

  private

  def with_app_name(name)
    original = I18n.t("app_name", locale: :es)
    I18n.backend.store_translations(:es, app_name: name)
    yield
  ensure
    I18n.backend.store_translations(:es, app_name: original)
  end
end
