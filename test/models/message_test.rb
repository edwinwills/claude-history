require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "content_blocks returns array from message.content array" do
    c = make_conversation
    raw = { "type" => "user", "message" => { "content" => [ { "type" => "text", "text" => "hi" } ] } }
    m = Message.create!(conversation: c, record_type: "user", role: "user", position: 0, raw: raw.to_json)
    assert_equal [ { "type" => "text", "text" => "hi" } ], m.content_blocks
  end

  test "content_blocks wraps bare string content" do
    c = make_conversation
    raw = { "type" => "user", "message" => { "content" => "plain string" } }
    m = Message.create!(conversation: c, record_type: "user", role: "user", position: 0, raw: raw.to_json)
    assert_equal [ { "type" => "text", "text" => "plain string" } ], m.content_blocks
  end

  test "content_blocks returns [] for records without message" do
    c = make_conversation
    m = Message.create!(conversation: c, record_type: "system", position: 0, raw: { "type" => "system" }.to_json)
    assert_equal [], m.content_blocks
  end
end
