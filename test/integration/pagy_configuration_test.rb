require "test_helper"

class PagyConfigurationTest < ActiveSupport::TestCase
  test "translates its navigation through the request locale" do
    assert_equal "Siguiente", I18n.with_locale(:es) { Pagy::I18n.translate("pagy.aria_label.next") }
    assert_equal "Next", I18n.with_locale(:en) { Pagy::I18n.translate("pagy.aria_label.next") }
  end
end
