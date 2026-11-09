require "test_helper"

class StatsControllerTest < ActionDispatch::IntegrationTest
  test "renders each period" do
    conv = make_conversation(title: "Busy session")
    Message.create!(conversation: conv, record_type: "assistant", role: "assistant", position: 0,
                    timestamp: 1.hour.ago, model: "claude-opus-5-5", api_message_id: "m1",
                    input_tokens: 3, output_tokens: 42, cache_creation_tokens: 0, cache_read_tokens: 0,
                    raw: { "message" => { "content" => [ { "type" => "tool_use", "name" => "Bash" } ] } }.to_json)

    %w[day week month].each do |period|
      get stats_path(period: period)
      assert_response :success
      assert_match "claude-opus-5-5", response.body
      assert_match "Busy session", response.body
      assert_match "Bash", response.body
    end
  end

  test "renders empty state" do
    get stats_path
    assert_response :success
    assert_match(/No Claude Code activity/, response.body)
  end
end
