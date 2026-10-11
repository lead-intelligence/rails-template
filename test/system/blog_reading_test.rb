require "application_system_test_case"

class BlogReadingTest < ApplicationSystemTestCase
  test "pages through the published posts" do
    (BlogController::PER_PAGE + 1).times do |index|
      Railspress::Post.create!(title: "Post #{index}", status: :published, published_at: index.hours.ago)
    end

    visit blog_path
    assert_selector "article", count: BlogController::PER_PAGE

    find("nav.pagy a[aria-label='#{t("pagy.aria_label.next")}']").click

    assert_current_path blog_path(page: 2)
    assert_selector "article", count: 1
    assert_text "Post #{BlogController::PER_PAGE}"
  end
end
