require "test_helper"

class ClaudeDesktop::ClientTest < ActiveSupport::TestCase
  test "rejects empty session key" do
    assert_raises(ArgumentError) { ClaudeDesktop::Client.new(session_key: "") }
  end

  test "uses injected http callable and returns parsed JSON" do
    calls = []
    http = ->(path) {
      calls << path
      { "ok" => true }
    }
    client = ClaudeDesktop::Client.new(session_key: "sk-ant-test", http: http)
    result = client.organizations
    assert_equal({ "ok" => true }, result)
    assert_equal [ "/api/organizations" ], calls
  end

  test "BASE targets claude.ai (not api.claude.ai — that host doesn't resolve)" do
    assert_equal "https://claude.ai", ClaudeDesktop::Client::BASE
  end

  test "format_cookie leaves a full Cookie header untouched" do
    client = ClaudeDesktop::Client.new(session_key: "sk")
    full = "sessionKey=sk-ant-sid01-abc; cf_clearance=xyz; intercom=1"
    assert_equal full, client.send(:format_cookie, full)
  end

  test "format_cookie wraps a bare sessionKey value" do
    client = ClaudeDesktop::Client.new(session_key: "sk")
    assert_equal "sessionKey=sk-ant-sid01-abc", client.send(:format_cookie, "sk-ant-sid01-abc")
  end

  test "format_cookie strips whitespace" do
    client = ClaudeDesktop::Client.new(session_key: "sk")
    assert_equal "sessionKey=abc", client.send(:format_cookie, "  abc\n")
  end

  test "user_agent defaults but accepts override" do
    default = ClaudeDesktop::Client.new(session_key: "sk")
    assert_equal ClaudeDesktop::Client::DEFAULT_USER_AGENT, default.instance_variable_get(:@user_agent)

    custom = "Mozilla/5.0 something-else"
    custom_client = ClaudeDesktop::Client.new(session_key: "sk", user_agent: custom)
    assert_equal custom, custom_client.instance_variable_get(:@user_agent)
  end

  test "user_agent with blank falls back to default" do
    c = ClaudeDesktop::Client.new(session_key: "sk", user_agent: "  ")
    assert_equal ClaudeDesktop::Client::DEFAULT_USER_AGENT, c.instance_variable_get(:@user_agent)
  end

  test "passes org + conversation ids in the paths" do
    calls = []
    http = ->(path) { calls << path; [] }
    client = ClaudeDesktop::Client.new(session_key: "sk", http: http)
    client.conversations("ORG1")
    client.conversation("ORG1", "CONV1")
    assert_equal "/api/organizations/ORG1/chat_conversations", calls[0]
    assert_equal "/api/organizations/ORG1/chat_conversations/CONV1?tree=True&rendering_mode=messages", calls[1]
  end
end
