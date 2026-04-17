require "test_helper"

class DesktopSyncsControllerTest < ActionDispatch::IntegrationTest
  setup { Setting.instance.update!(claude_ai_session_key: nil) }

  test "redirects to Settings with an alert when no key is configured" do
    with_env("CLAUDE_AI_SESSION_KEY", nil) do
      post desktop_sync_path
      assert_redirected_to setting_path
      follow_redirect!
      assert_match(/sessionKey/, response.body)
    end
  end

  test "uses the DB-stored session key with Importer.run" do
    Setting.instance.update!(claude_ai_session_key: "sk-from-db")
    calls = []
    with_importer_stub(->(**kwargs) {
      calls << kwargs
      ClaudeDesktop::Importer::Summary.new(organizations: 1, conversations_seen: 0, created: 0, updated: 0, skipped: 0, errors: 0)
    }) do
      with_env("CLAUDE_AI_SESSION_KEY", "sk-from-env") do
        post desktop_sync_path
      end
    end
    assert_redirected_to root_path
    assert_equal "sk-from-db", calls.first[:session_key], "DB value should win over env"
  end

  test "falls back to the env key when nothing is stored" do
    calls = []
    with_importer_stub(->(**kwargs) {
      calls << kwargs
      ClaudeDesktop::Importer::Summary.new(organizations: 1, conversations_seen: 0, created: 0, updated: 0, skipped: 0, errors: 0)
    }) do
      with_env("CLAUDE_AI_SESSION_KEY", "sk-env-only") do
        post desktop_sync_path
      end
    end
    assert_equal "sk-env-only", calls.first[:session_key]
  end

  test "auth errors surface as a flash alert" do
    Setting.instance.update!(claude_ai_session_key: "sk-expired")
    with_importer_stub(->(**) { raise ClaudeDesktop::Client::AuthError, "session expired" }) do
      post desktop_sync_path
    end
    assert_redirected_to root_path
    follow_redirect!
    assert_match(/session expired/, response.body)
  end

  private

  def with_env(key, value)
    old = ENV[key]
    value.nil? ? ENV.delete(key) : ENV[key] = value
    yield
  ensure
    ENV[key] = old
  end

  def with_importer_stub(callable)
    original = ClaudeDesktop::Importer.method(:run)
    ClaudeDesktop::Importer.define_singleton_method(:run) { |**kwargs| callable.call(**kwargs) }
    yield
  ensure
    ClaudeDesktop::Importer.define_singleton_method(:run, original)
  end
end
