require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup { Setting.instance.update!(claude_ai_session_key: nil) }

  test "show renders the form and the instructions" do
    get setting_path
    assert_response :success
    assert_match "claude.ai cookie", response.body
    assert_match "DevTools", response.body
    assert_match "sessionKey", response.body
    assert_match "cf_clearance", response.body
  end

  test "update saves the key" do
    patch setting_path, params: { setting: { claude_ai_session_key: "  sk-ant-new-value  " } }
    assert_redirected_to setting_path
    assert_equal "sk-ant-new-value", Setting.instance.claude_ai_session_key
  end

  test "destroy clears the key" do
    Setting.instance.update!(claude_ai_session_key: "sk-ant-stored")
    delete setting_path
    assert_redirected_to setting_path
    assert_nil Setting.instance.claude_ai_session_key
  end
end
