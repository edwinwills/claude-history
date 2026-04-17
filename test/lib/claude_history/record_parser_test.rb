require "test_helper"

class ClaudeHistory::RecordParserTest < ActiveSupport::TestCase
  P = ClaudeHistory::RecordParser

  test "extracts text from a user message with text blocks" do
    rec = { "type" => "user", "message" => { "content" => [ { "type" => "text", "text" => "hello" } ] } }
    assert_equal "hello", P.extract_text(rec)
  end

  test "extracts text from a string content field" do
    rec = { "type" => "user", "message" => { "content" => "hi there" } }
    assert_equal "hi there", P.extract_text(rec)
  end

  test "flattens tool_use blocks with name and truncated input" do
    rec = { "type" => "assistant", "message" => { "content" => [ { "type" => "tool_use", "name" => "Bash", "input" => { "cmd" => "ls" } } ] } }
    out = P.extract_text(rec)
    assert_includes out, "[tool_use: Bash]"
    assert_includes out, "ls"
  end

  test "flattens tool_result blocks" do
    rec = { "type" => "user", "message" => { "content" => [ { "type" => "tool_result", "content" => "file list" } ] } }
    assert_includes P.extract_text(rec), "file list"
  end

  test "flattens nested tool_result array content" do
    rec = { "type" => "user", "message" => { "content" => [ { "type" => "tool_result", "content" => [ { "type" => "text", "text" => "nested" } ] } ] } }
    assert_includes P.extract_text(rec), "nested"
  end

  test "flattens thinking blocks" do
    rec = { "type" => "assistant", "message" => { "content" => [ { "type" => "thinking", "thinking" => "hmm" } ] } }
    assert_equal "hmm", P.extract_text(rec)
  end

  test "system records yield their subtype" do
    assert_equal "turn_duration", P.extract_text({ "type" => "system", "subtype" => "turn_duration" })
  end

  test "progress and other unknown types yield empty string" do
    assert_equal "", P.extract_text({ "type" => "progress", "data" => { "foo" => "bar" } })
    assert_equal "", P.extract_text({ "type" => "pr-link" })
  end

  test "role_for returns user/assistant or nil" do
    assert_equal "user", P.role_for({ "type" => "user" })
    assert_equal "assistant", P.role_for({ "type" => "assistant" })
    assert_nil P.role_for({ "type" => "system" })
    assert_nil P.role_for({ "type" => "progress" })
  end

  test "truncates very long text blocks with ellipsis" do
    long = "x" * 3000
    rec = { "type" => "user", "message" => { "content" => [ { "type" => "text", "text" => long } ] } }
    out = P.extract_text(rec)
    assert_operator out.length, :<, 3000
    assert out.end_with?("…")
  end
end
