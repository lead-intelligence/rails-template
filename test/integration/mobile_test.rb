require "test_helper"

class MobileTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  NATIVE = { "User-Agent" => "Mozilla/5.0 (iPhone) Charco Mobile iOS/1.0/1 iOS/26.0/23A1 CharcoMobile/#{CharcoMobile::VERSION}" }.freeze

  test "a signed-out page carries an empty identity and no tabs, and keeps the web navbar" do
    get root_url, headers: NATIVE

    assert_select "[data-native-identity='']"
    assert_select "[data-native-tabs]", false
    assert_select "[data-native-badge]", false
    assert_select ".navbar", false
    assert_select "main.native-inset"
  end

  test "a browser keeps the web navbar and never sees the native inset" do
    get root_url

    assert_select ".navbar"
    assert_select "main.mt-6"
    assert_select "[data-native-identity='']"
  end

  test "a signed-in page carries the identity, the tab bar and the badge" do
    sign_in_as users(:one)
    get root_url, headers: NATIVE

    token = css_select("[data-native-identity]").first["data-native-identity"]
    assert_match(/\A\h{16}\z/, token)
    assert_select "[data-native-tabs]"
    assert_select "[data-native-badge][data-native-badge-home='0'][data-native-badge-tab='0']"
  end

  test "a notice toasts in the app and stays a banner in the browser" do
    sign_in_as users(:one)

    patch profile_url, params: { user: { name: "Ada" } }
    follow_redirect!
    assert_select "[data-native-toast]", false
    assert_select "#flash .alert-success"

    patch profile_url, params: { user: { name: "Ada" } }, headers: NATIVE
    get response.location, headers: NATIVE
    assert_select "[data-native-toast]"
    assert_select "#flash .alert-success", false
  end

  test "form pages are marked so the app skips them on the way back" do
    get new_session_url
    assert_select "[data-native-form]"

    get new_registration_url
    assert_select "[data-native-form]"
  end

  test "the config document carries every tab with its title in both locales" do
    get "/native/config"

    assert_response :success
    tabs = response.parsed_body["tabs"]
    assert_equal %w[home chats documents notifications profile], tabs.map { |tab| tab["key"] }
    assert_equal({ "es" => I18n.t("charco_mobile.tabs.home.title", locale: :es), "en" => I18n.t("charco_mobile.tabs.home.title", locale: :en) }, tabs.first["titles"])
    assert_equal "house", tabs.first["icon"]
    assert_equal [ "/profile/edit", "/profile", "/active_sessions", "/feedback" ], tabs.last["auto_route"]
    assert_equal true, tabs.find { |tab| tab["key"] == "documents" }["search"]
    assert_equal "normal", response.parsed_body.dig("app", "mode")
    assert_equal "/", response.parsed_body.dig("app", "entry_path")
    assert_equal I18n.t("charco_mobile.errors.retry", locale: :es), response.parsed_body.dig("errors", "retry", "es")
    assert_equal true, response.parsed_body.dig("security", "biometric_lock")
    assert_equal I18n.t("charco_mobile.security.lock.unlock", locale: :es), response.parsed_body.dig("security", "copy", "es", "unlock")
    assert_equal I18n.t("charco_mobile.scanner.title", locale: :es), response.parsed_body.dig("scanner", "copy", "es", "title")
    assert_equal I18n.t("charco_mobile.scanner.denied", locale: :en), response.parsed_body.dig("scanner", "copy", "en", "denied")
  end

  test "the config document carries the splash color and an empty navbar" do
    get "/native/config"

    appearance = response.parsed_body["appearance"]
    assert_equal "#FFFFFF", appearance.dig("splash", "background_color", "light")
    assert_equal appearance.dig("background_color", "dark"), appearance.dig("splash", "background_color", "dark")
    assert_nil appearance.dig("splash", "image")
    assert appearance.key?("navbar")
    assert appearance["navbar"].key?("status_bar")
    assert_nil appearance.dig("navbar", "status_bar")
  end

  test "the document search offers a scan button that fills the query and submits, only in the app" do
    sign_in_as users(:one)
    get documents_url, headers: NATIVE

    button = css_select("button#scan.native-only").first
    assert_equal I18n.t("documents.index.scan"), button.text
    assert_equal({ "target" => "#q", "submit" => true }, JSON.parse(button["data-native-scan"]))
    assert_select "form button#scan", false
  end

  test "the document search moves into the native search field, which mirrors the hidden web form" do
    sign_in_as users(:one)
    stub_openai_embedding(vector: Array.new(Document::EMBEDDING_DIMENSIONS, 0.0))
    get documents_url(q: "ada"), headers: NATIVE

    assert_select "[data-native-search='#q'][data-native-placeholder='#{I18n.t("documents.index.search_placeholder")}']"
    assert_select "[data-native-search][data-native-submit]", false
    assert_select "form.native-hidden[action='#{documents_path}'] input#q[value='ada']"
  end
end

class MobileNavbarTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  NATIVE = MobileTest::NATIVE

  test "a browser never sees the native navigation bar" do
    get root_url
    assert_select "[data-native-navbar]", false
    assert_select "#native-sign-out", false
  end

  test "a signed-out page titles the bar and offers sign in" do
    get root_url, headers: NATIVE
    assert_select "[data-native-navbar='#{I18n.t("pages.home.meta_title")}']"
    assert_select "[data-native-button][data-native-title='#{I18n.t("shared.navbar.sign_in")}'][data-native-href='#{new_session_path}']"
    assert_select "[data-native-menu-item]", false
  end

  test "a signed-in page carries the menu and the hidden sign-out button it clicks" do
    sign_in_as users(:one)
    get chats_url, headers: NATIVE
    assert_select "[data-native-navbar='#{I18n.t("chats.index.title")}']"
    assert_select "[data-native-button][data-native-title='#{I18n.t("shared.navbar.more")}'][data-native-icon='ellipsis.circle']" do
      assert_select "[data-native-menu-item]", 4
      assert_select "[data-native-menu-item][data-native-click='#native-sign-out'][data-native-destructive='true']"
    end
    assert_select "form.native-hidden button#native-sign-out.native-hidden"
  end
end

class MobileChatsTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  test "the chat list offers a floating button and a native menu per row" do
    sign_in_as users(:one)
    chat = users(:one).chats.create!
    get chats_url, headers: MobileTest::NATIVE

    assert_select "[data-native-fab][data-native-icon='plus'][data-native-href='#{new_chat_path}'][data-native-color='tint']"
    assert_select "[data-native-menu][data-native-anchor='##{dom_id(chat, :row)}']" do
      assert_select "[data-native-menu-item][data-native-href='#{chat_path(chat)}']"
      assert_select "[data-native-menu-item][data-native-click='##{dom_id(chat, :destroy)}'][data-native-destructive='true']"
    end
    assert_select "li##{dom_id(chat, :row)}"

    get chat_url(chat), headers: MobileTest::NATIVE
    assert_select "[data-native-keyboard-toolbar='false']"
  end
end

class MobilePushTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  test "a signed-in page asks for push permission and the app registers its device" do
    sign_in_as users(:one)
    get root_url, headers: MobileTest::NATIVE
    assert_select "[data-native-push]"

    post "/native/push/devices", params: { token: "abc", platform: "apple", name: "iPhone" }, headers: MobileTest::NATIVE
    assert_response :no_content

    device = users(:one).push_devices.sole
    assert_equal [ "abc", "apple", "iPhone" ], [ device.token, device.platform, device.name ]
  end

  test "a signed-out page never asks and the endpoint redirects to sign in" do
    get root_url, headers: MobileTest::NATIVE
    assert_select "[data-native-push]", false

    post "/native/push/devices", params: { token: "abc", platform: "apple" }, headers: MobileTest::NATIVE
    assert_redirected_to new_session_url
  end

  test "a token another person registered on the same phone moves to whoever signs in" do
    users(:two).push_devices.create!(token: "abc", platform: "apple", name: "iPhone")
    sign_in_as users(:one)

    post "/native/push/devices", params: { token: "abc", platform: "apple", name: "iPhone" }, headers: MobileTest::NATIVE
    assert_response :no_content

    assert_equal users(:one), ApplicationPushDevice.sole.owner
    assert_empty users(:two).push_devices.reload
  end

  test "a platform Action Push Native cannot deliver to is refused and stores nothing" do
    sign_in_as users(:one)

    post "/native/push/devices", params: { token: "abc", platform: "ios" }, headers: MobileTest::NATIVE
    assert_response :unprocessable_content
    assert_equal 0, ApplicationPushDevice.count
  end

  test "after signing out the app deletes its token with nobody signed in, past the sign-in gate" do
    users(:one).push_devices.create!(token: "abc", platform: "apple")

    delete "/native/push/devices/abc", headers: MobileTest::NATIVE
    assert_response :no_content
    assert_equal 0, ApplicationPushDevice.count

    delete "/native/push/devices/abc", headers: MobileTest::NATIVE
    assert_response :no_content
  end

  test "devices leave with the account and land in the data export" do
    user = users(:one)
    user.push_devices.create!(token: "abc", platform: "apple")
    assert_difference -> { ApplicationPushDevice.count }, -1 do
      user.destroy
    end
  end
end
