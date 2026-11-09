require "test_helper"

class SubagentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @conv = make_conversation(title: "Parent session")
    @sub = Subagent.create!(conversation: @conv, agent_id: "abc", agent_type: "Explore",
                            description: "Explore the codebase", tool_use_id: "toolu_1", file_path: "/tmp/abc.jsonl", message_count: 1)
    Message.create!(conversation: @conv, record_type: "assistant", role: "assistant", position: 0,
                    raw: { "message" => { "content" => [ { "type" => "tool_use", "id" => "toolu_1", "name" => "Agent", "input" => {} } ] } }.to_json)
    Message.create!(conversation: @conv, subagent: @sub, record_type: "assistant", role: "assistant", position: 0,
                    output_tokens: 12, raw: { "message" => { "content" => [ { "type" => "text", "text" => "subagent says hi" } ] } }.to_json)
  end

  test "shows the subagent transcript" do
    get conversation_subagent_path(@conv, @sub)
    assert_response :success
    assert_match "Explore the codebase", response.body
    assert_match "subagent says hi", response.body
  end

  test "parent conversation lists subagents and links the spawning tool call" do
    get conversation_path(@conv)
    assert_response :success
    assert_match "Subagents (1)", response.body
    assert_match "View Explore subagent transcript", response.body
    assert_no_match(/subagent says hi/, response.body)
  end

  test "404s for a subagent of another conversation" do
    other = make_conversation
    get conversation_subagent_path(other, @sub)
    assert_response :not_found
  end
end
