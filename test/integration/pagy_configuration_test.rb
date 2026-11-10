require "test_helper"

class PagyConfigurationTest < ActiveSupport::TestCase
  test "translates its navigation through the request locale" do
    assert_equal "Siguiente", I18n.with_locale(:es) { Pagy::I18n.translate("pagy.aria_label.next") }
    assert_equal "Next", I18n.with_locale(:en) { Pagy::I18n.translate("pagy.aria_label.next") }
  end

  test "every list sends a page past the last one to the last page" do
    calls = Rails.root.glob("app/controllers/**/*.rb").flat_map { |file| file.read.scan(/\bpagy\(.*\)/) }

    assert_not_empty calls
    assert_empty calls.grep_v(/raise_range_error: true|\Apagy\(:keyset/),
      "Without raise_range_error, a page number past the 64-bit range reaches SQLite as the offset and fails."
  end
end
