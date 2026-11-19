require "application_system_test_case"

class PhoneFitTest < ApplicationSystemTestCase
  SHRINKS_A_FRAME_AFTER_RESIZE = <<~JS.freeze
    var box = document.createElement("div");
    box.style.width = "600px";
    document.body.append(box);
    new ResizeObserver(function () {
      requestAnimationFrame(function () {
        box.style.width = window.innerWidth > 400 ? "600px" : "100px";
      });
    }).observe(document.documentElement);
  JS

  test "measures the phone layout after a resize observer's next frame" do
    visit root_url
    page.execute_script(SHRINKS_A_FRAME_AFTER_RESIZE)

    assert_fits_phone
  end
end
