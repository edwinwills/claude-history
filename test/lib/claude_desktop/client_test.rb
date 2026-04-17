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
