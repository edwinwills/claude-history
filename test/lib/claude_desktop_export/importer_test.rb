require "test_helper"
require "zip"
require "stringio"

class ClaudeDesktopExport::ImporterTest < ActiveSupport::TestCase
  def ts(offset = 0)
    (Time.current + offset).iso8601(6)
  end

  def make_zip_bytes(entries)
    io = StringIO.new
    Zip::OutputStream.write_buffer(io) do |zos|
      entries.each { |name, body| zos.put_next_entry(name); zos.write(body) }
    end
    io.rewind
    io.read
  end

  def attach_zip(record, entries)
    record.archive.attach(
      io: StringIO.new(make_zip_bytes(entries)),
      filename: "claude_export.zip",
      content_type: "application/zip"
    )
  end

  def conversations_fixture(overrides = {})
    msgs = [
      { "uuid" => "M1", "sender" => "human", "text" => "hello",
        "created_at" => ts(-3500), "content" => [ { "type" => "text", "text" => "hello" } ] },
      { "uuid" => "M2", "sender" => "assistant", "text" => "hi",
        "created_at" => ts(-3400), "content" => [ { "type" => "text", "text" => "hi friend" } ] }
    ]
    [
      {
        "uuid" => "CONV-1",
        "name" => "First chat",
        "created_at" => ts(-3600),
        "updated_at" => ts(-60),
        "chat_messages" => msgs
      }.merge(overrides)
    ]
  end

  def make_import(entries)
    import = DesktopImport.create!(status: "pending")
    attach_zip(import, entries)
    import
  end

  test "imports a ZIP and creates project + conversation + messages" do
    import = make_import("conversations.json" => conversations_fixture.to_json)
    record = ClaudeDesktopExport::Importer.run(import: import, logger: Logger.new(IO::NULL))

    assert_equal "succeeded", record.status
    assert_equal 1, record.conversations_seen
    assert_equal 1, record.conversations_created

    project = Project.find_by(path: ClaudeDesktopExport::Importer::PROJECT_PATH)
    assert_equal "Claude Desktop", project.name

    conv = Conversation.find_by(session_id: "CONV-1")
    assert conv.desktop?
    assert_equal "First chat", conv.title
    assert_equal 2, conv.message_count
    assert_equal %w[user assistant], conv.messages.order(:position).map(&:role)
  end

  test "re-uploading the same export is idempotent" do
    ClaudeDesktopExport::Importer.run(
      import: make_import("conversations.json" => conversations_fixture.to_json),
      logger: Logger.new(IO::NULL)
    )
    record = ClaudeDesktopExport::Importer.run(
      import: make_import("conversations.json" => conversations_fixture.to_json),
      logger: Logger.new(IO::NULL)
    )

    assert_equal 1, record.conversations_seen
    assert_equal 0, record.conversations_created
    assert_equal 1, record.conversations_skipped
  end

  test "re-uploading a newer export updates" do
    ClaudeDesktopExport::Importer.run(
      import: make_import("conversations.json" => conversations_fixture.to_json),
      logger: Logger.new(IO::NULL)
    )

    newer = conversations_fixture.first.merge("updated_at" => ts(0))
    newer["chat_messages"] << { "uuid" => "M3", "sender" => "human", "text" => "and another",
                                 "created_at" => ts(-1), "content" => [ { "type" => "text", "text" => "and another" } ] }
    record = ClaudeDesktopExport::Importer.run(
      import: make_import("conversations.json" => [ newer ].to_json),
      logger: Logger.new(IO::NULL)
    )

    assert_equal 1, record.conversations_updated
    assert_equal 3, Conversation.find_by(session_id: "CONV-1").message_count
  end

  test "soft-deleted conversations are never resurrected" do
    ClaudeDesktopExport::Importer.run(
      import: make_import("conversations.json" => conversations_fixture.to_json),
      logger: Logger.new(IO::NULL)
    )
    Conversation.find_by(session_id: "CONV-1").soft_delete!

    newer = conversations_fixture.first.merge("updated_at" => ts(0))
    record = ClaudeDesktopExport::Importer.run(
      import: make_import("conversations.json" => [ newer ].to_json),
      logger: Logger.new(IO::NULL)
    )

    assert_equal 1, record.conversations_skipped
    assert_nil Conversation.find_by(session_id: "CONV-1")
    assert Conversation.with_deleted.exists?(session_id: "CONV-1")
  end

  test "reports failed status when conversations.json is missing" do
    record = ClaudeDesktopExport::Importer.run(
      import: make_import("users.json" => "[]"),
      logger: Logger.new(IO::NULL)
    )
    assert_equal "failed", record.status
    assert_match(/conversations\.json/, record.error_detail)
  end

  test "reports failed status when conversations.json is not JSON" do
    record = ClaudeDesktopExport::Importer.run(
      import: make_import("conversations.json" => "not json at all"),
      logger: Logger.new(IO::NULL)
    )
    assert_equal "failed", record.status
    assert_match(/not valid JSON/, record.error_detail)
  end

  test "reports failed when the archive is not a ZIP" do
    import = DesktopImport.create!(status: "pending")
    import.archive.attach(io: StringIO.new("not a zip at all"), filename: "bogus.zip", content_type: "application/zip")
    record = ClaudeDesktopExport::Importer.run(import: import, logger: Logger.new(IO::NULL))
    assert_equal "failed", record.status
    assert_match(/couldn't read ZIP/, record.error_detail)
  end

  test "reports failed when no archive is attached" do
    import = DesktopImport.create!(status: "pending")
    record = ClaudeDesktopExport::Importer.run(import: import, logger: Logger.new(IO::NULL))
    assert_equal "failed", record.status
    assert_match(/no ZIP attached/, record.error_detail)
  end

  test "continues past a single bad conversation entry" do
    convs = conversations_fixture + [ { "uuid" => "", "name" => "missing uuid" } ]
    record = ClaudeDesktopExport::Importer.run(
      import: make_import("conversations.json" => convs.to_json),
      logger: Logger.new(IO::NULL)
    )
    assert_equal "succeeded", record.status
    assert_equal 2, record.conversations_seen
    assert_equal 1, record.conversations_created
  end
end
