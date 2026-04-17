require "test_helper"

class SettingTest < ActiveSupport::TestCase
  setup { Setting.delete_all }

  test "instance creates a singleton row on first call" do
    assert_difference -> { Setting.count } => 1 do
      Setting.instance
    end
    assert_no_difference -> { Setting.count } do
      Setting.instance
    end
  end

  test "claude_ai_session_key prefers DB value" do
    ENV["CLAUDE_AI_SESSION_KEY"] = "env-val"
    Setting.instance.update!(claude_ai_session_key: "db-val")
    assert_equal "db-val", Setting.claude_ai_session_key
  ensure
    ENV.delete("CLAUDE_AI_SESSION_KEY")
  end

  test "claude_ai_session_key falls back to ENV when DB is blank" do
    ENV["CLAUDE_AI_SESSION_KEY"] = "env-val"
    assert_equal "env-val", Setting.claude_ai_session_key
  ensure
    ENV.delete("CLAUDE_AI_SESSION_KEY")
  end

  test "source_of_session_key reports the active source" do
    ENV.delete("CLAUDE_AI_SESSION_KEY")
    assert_equal :none, Setting.source_of_session_key

    ENV["CLAUDE_AI_SESSION_KEY"] = "e"
    assert_equal :env, Setting.source_of_session_key

    Setting.instance.update!(claude_ai_session_key: "d")
    assert_equal :database, Setting.source_of_session_key
  ensure
    ENV.delete("CLAUDE_AI_SESSION_KEY")
  end
end
