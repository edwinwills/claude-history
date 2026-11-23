require "test_helper"
require "tmpdir"
require "json"

class ClaudeHistory::SessionForkerTest < ActiveSupport::TestCase
  SESSION_ID = "22222222-2222-2222-2222-222222222222".freeze

  def rec(type, uuid, parent, content, **extra)
    { "type" => type, "uuid" => uuid, "parentUuid" => parent, "sessionId" => SESSION_ID,
      "message" => { "role" => type, "content" => content } }.merge(extra)
  end

  # u1 → a1 (tool_use) → r1 (tool_result) → a2 → u2 → a3, plus a metadata
  # record pointing at the final leaf and an abandoned branch off a1.
  def records
    [
      rec("user", "u1", nil, "first prompt"),
      rec("assistant", "a1", "u1", [ { "type" => "tool_use", "id" => "t1", "name" => "Bash", "input" => {} } ]),
      rec("assistant", "x1", "a1", "abandoned branch"),
      rec("user", "r1", "a1", [ { "type" => "tool_result", "tool_use_id" => "t1", "content" => "ok" } ], "toolUseResult" => {}),
      rec("assistant", "a2", "r1", [ { "type" => "text", "text" => "done" } ]),
      { "type" => "last-prompt", "leafUuid" => "a3", "sessionId" => SESSION_ID },
      rec("user", "u2", "a2", "second prompt"),
      rec("assistant", "a3", "u2", "second answer")
    ]
  end

  def with_session
    Dir.mktmpdir do |dir|
      path = File.join(dir, "#{SESSION_ID}.jsonl")
      File.write(path, records.map(&:to_json).join("\n") + "\n")
      conversation = make_conversation(session_id: SESSION_ID, file_path: path, cwd: "/tmp/my proj")
      yield conversation, dir
    end
  end

  def read_fork(fork)
    File.readlines(fork.file_path).map { |l| JSON.parse(l) }
  end

  test "forking from a prompt keeps that whole turn and its ancestors only" do
    with_session do |conversation, dir|
      fork = ClaudeHistory::SessionForker.call(conversation, "u1")

      assert_equal "a2", fork.message_uuid
      assert_equal File.join(dir, "#{fork.session_id}.jsonl"), fork.file_path
      lines = read_fork(fork)
      assert_equal %w[u1 a1 r1 a2], lines.map { |r| r["uuid"] }
      assert(lines.all? { |r| r["sessionId"] == fork.session_id })
      assert_equal "cd /tmp/my\\ proj && claude --resume #{fork.session_id} --fork-session", fork.resume_command
    end
  end

  test "forking mid-turn extends to the end of the turn" do
    with_session do |conversation, _dir|
      fork = ClaudeHistory::SessionForker.call(conversation, "a1")
      assert_equal %w[u1 a1 r1 a2], read_fork(fork).map { |r| r["uuid"] }
    end
  end

  test "forking from the last message keeps the full chain" do
    with_session do |conversation, _dir|
      fork = ClaudeHistory::SessionForker.call(conversation, "a3")
      assert_equal %w[u1 a1 r1 a2 u2 a3], read_fork(fork).map { |r| r["uuid"] }
    end
  end

  test "is idempotent per cut point" do
    with_session do |conversation, _dir|
      first = ClaudeHistory::SessionForker.call(conversation, "u1")
      second = ClaudeHistory::SessionForker.call(conversation, "a2")
      assert_equal first, second
      assert_equal 1, SessionFork.count
    end
  end

  test "raises for unknown messages and desktop conversations" do
    with_session do |conversation, _dir|
      assert_raises(ClaudeHistory::SessionForker::Error) { ClaudeHistory::SessionForker.call(conversation, "nope") }
      conversation.update!(source: "desktop")
      assert_raises(ClaudeHistory::SessionForker::Error) { ClaudeHistory::SessionForker.call(conversation, "u1") }
    end
  end

  test "importer skips fork files" do
    Dir.mktmpdir do |root|
      dir = File.join(root, "-tmp-proj")
      FileUtils.mkdir_p(dir)
      path = File.join(dir, "#{SESSION_ID}.jsonl")
      File.write(path, records.map { |r| r.merge("cwd" => "/tmp/proj") }.map(&:to_json).join("\n") + "\n")
      ClaudeHistory::Importer.run(root: root, logger: Logger.new(IO::NULL))
      conversation = Conversation.find_by!(session_id: SESSION_ID)

      fork = ClaudeHistory::SessionForker.call(conversation, "u1")
      summary = ClaudeHistory::Importer.run(root: root, logger: Logger.new(IO::NULL))

      assert_equal 0, summary.created
      assert_nil Conversation.with_deleted.find_by(session_id: fork.session_id)
    end
  end
end
