require "test_helper"

class PhotoTest < ActiveSupport::TestCase
  test "names the accepted formats the way a person knows them" do
    assert_equal "PNG, JPEG, WEBP", Photo.formats
  end

  test "states the size limit in words" do
    assert_equal ActiveSupport::NumberHelper.number_to_human_size(Photo::MAX_SIZE), Photo.max_size_in_words
  end

  test "the upload error states the formats and the size limit in every locale" do
    I18n.available_locales.each do |locale|
      error = I18n.t("support_chat_photos.create.upload_error", formats: "FORMATS", size: "SIZE", locale: locale)

      assert_includes error, "FORMATS"
      assert_includes error, "SIZE"
    end
  end

  test "every photo attachment follows the same rule" do
    [ [ User, :avatar ], [ Chat, :pending_photos ], [ Feedback, :photos ] ].each do |model, attachment|
      content_type = model.validators_on(attachment).find { |validator| validator.kind == :content_type }
      size = model.validators_on(attachment).find { |validator| validator.kind == :size }

      assert_equal Photo::CONTENT_TYPES, content_type.options[:in], "#{model}##{attachment}"
      assert_equal Photo::MAX_SIZE, size.options[:less_than], "#{model}##{attachment}"
    end
  end
end
