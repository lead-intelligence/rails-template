require "test_helper"

class ModelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_username = ENV["SUPERADMIN_USER"]
    @original_password = ENV["SUPERADMIN_PASSWORD"]
  end

  teardown do
    ENV["SUPERADMIN_USER"] = @original_username
    ENV["SUPERADMIN_PASSWORD"] = @original_password
  end

  def superadmin_headers
    { "Authorization" => "Basic #{Base64.strict_encode64("superadmin:secret")}" }
  end

  test "requires basic auth credentials" do
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"

    get models_url

    assert_response :unauthorized
  end

  test "denies access when no credentials are configured" do
    ENV["SUPERADMIN_USER"] = nil
    ENV["SUPERADMIN_PASSWORD"] = nil

    get models_url, headers: superadmin_headers

    assert_response :unauthorized
  end

  test "lists the available chat models for the superadmin" do
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"

    get models_url, headers: superadmin_headers

    assert_response :success
  end

  test "shows a model from the registry by its id, dots and all" do
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"

    get model_url("gpt-4.1-mini"), headers: superadmin_headers

    assert_response :success
    assert_includes response.body, RubyLLM.models.find("gpt-4.1-mini").name
  end

  test "answers not found for a model the registry does not have" do
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"

    get model_url("no-such-model"), headers: superadmin_headers

    assert_response :not_found
  end

  test "refreshes the model registry for the superadmin" do
    ENV["SUPERADMIN_USER"] = "superadmin"
    ENV["SUPERADMIN_PASSWORD"] = "secret"

    refreshed = false
    RubyLLM.models.define_singleton_method(:refresh) { refreshed = true }
    begin
      post refresh_models_url, headers: superadmin_headers
    ensure
      RubyLLM.models.singleton_class.send(:remove_method, :refresh)
    end

    assert refreshed
    assert_redirected_to models_path
  end
end
