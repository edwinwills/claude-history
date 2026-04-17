require "test_helper"
require "stringio"

class ClaudeDesktopExport::JsonUploadTest < ActiveSupport::TestCase
  def ts(offset = 0) = (Time.current + offset).iso8601(6)

  def attach_json(record, body, filename: "claude-export.json")
    record.archive.attach(
      io: StringIO.new(body),
      filename: filename,
      content_type: "application/json"
    )
  end

  test "a bare .json file skips the ZIP path and imports directly" do
    import = DesktopImport.create!(status: "pending")
    body = [
      { "uuid" => "JSON-1", "name" => "From bookmarklet",
        "created_at" => ts(-3600), "updated_at" => ts(-60),
        "chat_messages" => [
          { "uuid" => "M1", "sender" => "human", "text" => "hi",
            "created_at" => ts(-3500), "content" => [ { "type" => "text", "text" => "hi" } ] }
        ] }
    ].to_json
    attach_json(import, body)

    record = ClaudeDesktopExport::Importer.run(import: import, logger: Logger.new(IO::NULL))
    assert_equal "succeeded", record.status
    assert_equal 1, record.conversations_created

    conv = Conversation.find_by(session_id: "JSON-1")
    assert conv.desktop?
    assert_equal "From bookmarklet", conv.title
    assert_equal 1, conv.messages.count
  end

  test "malformed JSON lands as a failed import" do
    import = DesktopImport.create!(status: "pending")
    attach_json(import, "not valid json")
    record = ClaudeDesktopExport::Importer.run(import: import, logger: Logger.new(IO::NULL))
    assert_equal "failed", record.status
    assert_match(/not valid JSON/, record.error_detail)
  end

  test "JSON that isn't an array lands as a failed import" do
    import = DesktopImport.create!(status: "pending")
    attach_json(import, { "oops" => true }.to_json)
    record = ClaudeDesktopExport::Importer.run(import: import, logger: Logger.new(IO::NULL))
    assert_equal "failed", record.status
    assert_match(/is not a JSON array/, record.error_detail)
  end
end
