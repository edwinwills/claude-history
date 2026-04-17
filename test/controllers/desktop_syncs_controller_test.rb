require "test_helper"

class DesktopSyncsControllerTest < ActionDispatch::IntegrationTest
  test "without CLAUDE_AI_SESSION_KEY it redirects with an alert" do
    with_env("CLAUDE_AI_SESSION_KEY", nil) do
      post desktop_sync_path
      assert_redirected_to root_path
      follow_redirect!
      assert_match(/CLAUDE_AI_SESSION_KEY/, response.body)
    end
  end

  test "calls Importer.run with the env session key" do
    calls = []
    with_importer_stub(->(**kwargs) {
      calls << kwargs
      ClaudeDesktop::Importer::Summary.new(organizations: 1, conversations_seen: 0, created: 0, updated: 0, skipped: 0, errors: 0)
    }) do
      with_env("CLAUDE_AI_SESSION_KEY", "sk-ant-test") do
        post desktop_sync_path
      end
    end

    assert_redirected_to root_path
    assert_equal 1, calls.size
    assert_equal "sk-ant-test", calls.first[:session_key]
  end

  test "auth errors surface as a flash alert" do
    with_importer_stub(->(**) { raise ClaudeDesktop::Client::AuthError, "session expired" }) do
      with_env("CLAUDE_AI_SESSION_KEY", "sk-ant-expired") do
        post desktop_sync_path
      end
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
