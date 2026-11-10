require "test_helper"

class MessagesHelperTest < ActionView::TestCase
  test "default_model_display_name shows the configured default model's label" do
    default_model = RubyLLM.models.find(RubyLLM.config.default_model)

    assert_equal I18n.t("messages.default_model", model: default_model.label), default_model_display_name
  end

  test "tool_result_partial falls back to default when the object has no parent_tool_call" do
    assert_equal "messages/tool_results/default", tool_result_partial(Object.new)
  end

  test "tool_result_partial falls back to default when parent_tool_call is nil" do
    message = Struct.new(:parent_tool_call).new(nil)

    assert_equal "messages/tool_results/default", tool_result_partial(message)
  end

  test "tool_result_partial falls back to default when no matching partial exists for the tool name" do
    tool_call = Struct.new(:name).new("search")
    message = Struct.new(:parent_tool_call).new(tool_call)

    assert_equal "messages/tool_results/default", tool_result_partial(message)
  end

  test "tool_call_partial resolves the default template when its name matches an existing partial" do
    tool_call = Struct.new(:name).new("default")

    assert_equal "messages/tool_calls/default", tool_call_partial(tool_call)
  end
end
