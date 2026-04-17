require "test_helper"
require "zip"
require "stringio"

class DesktopImportsControllerTest < ActionDispatch::IntegrationTest
  def zip_upload(entries)
    io = StringIO.new
    Zip::OutputStream.write_buffer(io) do |zos|
      entries.each { |name, body| zos.put_next_entry(name); zos.write(body) }
    end
    io.rewind
    Rack::Test::UploadedFile.new(io, "application/zip", original_filename: "claude_export.zip")
  end

  def ts(offset = 0) = (Time.current + offset).iso8601(6)

  test "index renders even when there are no imports" do
    get desktop_imports_path
    assert_response :success
    assert_match "No imports yet", response.body
  end

  test "upload stores the archive as an Active Storage attachment and runs the importer" do
    convs = [ { "uuid" => "A1", "name" => "Upload test", "created_at" => ts(-60), "updated_at" => ts(-30), "chat_messages" => [] } ]
    file = zip_upload("conversations.json" => convs.to_json)

    assert_difference -> { DesktopImport.count } => 1,
                      -> { Conversation.count } => 1,
                      -> { ActiveStorage::Attachment.count } => 1 do
      post desktop_imports_path, params: { archive: file }
    end

    import = DesktopImport.order(:id).last
    assert import.archive.attached?
    assert_equal "claude_export.zip", import.archive.filename.to_s
    assert_equal "succeeded", import.status

    assert_redirected_to desktop_imports_path
    follow_redirect!
    assert_match "Import finished", response.body
  end

  test "missing file redirects with an alert" do
    post desktop_imports_path, params: {}
    assert_redirected_to desktop_imports_path
    follow_redirect!
    assert_match "Choose a ZIP file", response.body
  end

  test "malformed ZIP is recorded as a failed import" do
    bad = Rack::Test::UploadedFile.new(StringIO.new("not a zip"), "application/zip", original_filename: "bogus.zip")
    assert_difference -> { DesktopImport.count } => 1, -> { Conversation.count } => 0 do
      post desktop_imports_path, params: { archive: bad }
    end
    assert_redirected_to desktop_imports_path
    follow_redirect!
    assert_match "Import failed", response.body
  end
end
