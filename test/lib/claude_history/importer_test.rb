require "test_helper"
require "tmpdir"
require "json"

class ClaudeHistory::ImporterTest < ActiveSupport::TestCase
  def write_session(root, cwd, session_id, records)
    encoded = cwd.sub(/\A\//, "-").tr("/", "-")
    dir = File.join(root, encoded)
    FileUtils.mkdir_p(dir)
    path = File.join(dir, "#{session_id}.jsonl")
    File.open(path, "w") { |f| records.each { |r| f.puts(r.to_json) } }
    path
  end

  def basic_records(cwd, session_id, slug: "my-session", git_branch: "main")
    ts = ->(offset) { (Time.current + offset).iso8601(6) }
    [
      { "type" => "user", "uuid" => "u1", "parentUuid" => nil, "timestamp" => ts.call(-60),
        "sessionId" => session_id, "cwd" => cwd, "gitBranch" => git_branch, "slug" => slug,
        "message" => { "role" => "user", "content" => [ { "type" => "text", "text" => "hello claude" } ] } },
      { "type" => "assistant", "uuid" => "a1", "parentUuid" => "u1", "timestamp" => ts.call(-30),
        "sessionId" => session_id, "cwd" => cwd,
        "message" => { "role" => "assistant", "content" => [ { "type" => "text", "text" => "hi there friend" } ] } },
      { "type" => "system", "subtype" => "turn_duration", "durationMs" => 100,
        "sessionId" => session_id, "timestamp" => ts.call(-20) }
    ]
  end

  test "imports a single JSONL file into project + conversation + messages" do
    Dir.mktmpdir do |root|
      cwd = "/Users/test/code/cool-project"
      session_id = "11111111-1111-1111-1111-111111111111"
      write_session(root, cwd, session_id, basic_records(cwd, session_id))

      summary = ClaudeHistory::Importer.run(root: root, logger: Logger.new(IO::NULL))
      assert_equal 1, summary.files_seen
      assert_equal 1, summary.created
      assert_equal 0, summary.errors

      project = Project.find_by(path: cwd)
      assert_not_nil project
      assert_equal "cool-project", project.name

      conv = Conversation.find_by(session_id: session_id)
      assert_not_nil conv
      assert_equal "main", conv.git_branch
      assert_equal 2, conv.message_count  # user + assistant only
      assert_equal 3, conv.messages.count # includes system
      assert_equal "My Session", conv.display_title
    end
  end

  test "re-running with unchanged mtime skips the file" do
    Dir.mktmpdir do |root|
      cwd = "/Users/test/code/proj"
      sid = "22222222-2222-2222-2222-222222222222"
      write_session(root, cwd, sid, basic_records(cwd, sid))

      ClaudeHistory::Importer.run(root: root, logger: Logger.new(IO::NULL))
      summary = ClaudeHistory::Importer.run(root: root, logger: Logger.new(IO::NULL))
      assert_equal 1, summary.skipped
      assert_equal 0, summary.created
      assert_equal 0, summary.updated
    end
  end

  test "does not resurrect a soft-deleted conversation on re-sync" do
    Dir.mktmpdir do |root|
      cwd = "/Users/test/code/gone"
      sid = "33333333-3333-3333-3333-333333333333"
      path = write_session(root, cwd, sid, basic_records(cwd, sid))

      ClaudeHistory::Importer.run(root: root, logger: Logger.new(IO::NULL))
      conv = Conversation.find_by(session_id: sid)
      conv.soft_delete!

      # bump file mtime so the skip-on-unchanged path doesn't hide the real behaviour
      future = (Time.current + 60).to_time
      File.utime(future, future, path)

      ClaudeHistory::Importer.run(root: root, logger: Logger.new(IO::NULL))
      assert_nil Conversation.find_by(session_id: sid), "importer resurrected soft-deleted conv"
      assert Conversation.with_deleted.exists?(session_id: sid)
    end
  end

  test "extracts slug-derived title and falls back to first user message" do
    Dir.mktmpdir do |root|
      cwd = "/Users/test/code/nolug"
      sid = "44444444-4444-4444-4444-444444444444"
      records = basic_records(cwd, sid)
      records.each { |r| r.delete("slug") }
      write_session(root, cwd, sid, records)

      ClaudeHistory::Importer.run(root: root, logger: Logger.new(IO::NULL))
      conv = Conversation.find_by(session_id: sid)
      assert_equal "hello claude", conv.title
    end
  end

  test "handles malformed lines without crashing the file" do
    Dir.mktmpdir do |root|
      cwd = "/Users/test/code/messy"
      sid = "55555555-5555-5555-5555-555555555555"
      dir = File.join(root, "-Users-test-code-messy")
      FileUtils.mkdir_p(dir)
      path = File.join(dir, "#{sid}.jsonl")
      File.open(path, "w") do |f|
        f.puts "this is not json"
        basic_records(cwd, sid).each { |r| f.puts(r.to_json) }
        f.puts '{"bad": '
      end

      summary = ClaudeHistory::Importer.run(root: root, logger: Logger.new(IO::NULL))
      assert_equal 1, summary.created
      assert_equal 0, summary.errors
      conv = Conversation.find_by(session_id: sid)
      assert_equal 2, conv.message_count
    end
  end

  test "extracts model and token usage, keeping it on one record per API response" do
    Dir.mktmpdir do |root|
      cwd = "/Users/test/code/usage"
      sid = "33333333-3333-3333-3333-333333333333"
      usage = { "input_tokens" => 5, "output_tokens" => 40, "cache_creation_input_tokens" => 100, "cache_read_input_tokens" => 900 }
      ts = Time.current.iso8601(6)
      assistant = ->(uuid, block) {
        { "type" => "assistant", "uuid" => uuid, "timestamp" => ts, "sessionId" => sid, "cwd" => cwd,
          "message" => { "id" => "msg_1", "model" => "claude-opus-5-5", "role" => "assistant", "usage" => usage, "content" => [ block ] } }
      }
      records = [
        { "type" => "user", "uuid" => "u1", "timestamp" => ts, "sessionId" => sid, "cwd" => cwd,
          "message" => { "role" => "user", "content" => "hi" } },
        assistant.call("a1", { "type" => "thinking", "thinking" => "hmm" }),
        assistant.call("a2", { "type" => "text", "text" => "hello" }),
        { "type" => "assistant", "uuid" => "a3", "timestamp" => ts, "sessionId" => sid, "cwd" => cwd,
          "message" => { "id" => "msg_2", "model" => "<synthetic>", "role" => "assistant",
                         "usage" => { "input_tokens" => 0, "output_tokens" => 0 }, "content" => [ { "type" => "text", "text" => "err" } ] } }
      ]
      write_session(root, cwd, sid, records)
      ClaudeHistory::Importer.run(root: root, logger: Logger.new(IO::NULL))

      msgs = Conversation.find_by(session_id: sid).messages.where(record_type: "assistant").to_a
      assert_equal [ "claude-opus-5-5", "claude-opus-5-5", nil ], msgs.map(&:model)
      assert_equal [ nil, 40, 0 ], msgs.map(&:output_tokens)
      assert_equal 900, msgs[1].cache_read_tokens
      assert_equal 100, msgs[1].cache_creation_tokens
      assert_equal 5, msgs[1].input_tokens
      assert_nil Conversation.find_by(session_id: sid).messages.find_by(record_type: "user").model
    end
  end

  def write_subagent(root, cwd, session_id, agent_id, records, meta: nil)
    encoded = cwd.sub(/\A\//, "-").tr("/", "-")
    dir = File.join(root, encoded, session_id, "subagents")
    FileUtils.mkdir_p(dir)
    path = File.join(dir, "agent-#{agent_id}.jsonl")
    File.open(path, "w") { |f| records.each { |r| f.puts(r.to_json) } }
    File.write(File.join(dir, "agent-#{agent_id}.meta.json"), meta.to_json) if meta
    path
  end

  def subagent_records(cwd, session_id, agent_id)
    ts = Time.current.iso8601(6)
    usage = { "input_tokens" => 1, "output_tokens" => 50, "cache_creation_input_tokens" => 0, "cache_read_input_tokens" => 0 }
    [
      { "type" => "user", "uuid" => "su1", "isSidechain" => true, "agentId" => agent_id, "sessionId" => session_id,
        "cwd" => cwd, "timestamp" => ts, "message" => { "role" => "user", "content" => "find the thing" } },
      { "type" => "assistant", "uuid" => "sa1", "isSidechain" => true, "agentId" => agent_id, "sessionId" => session_id,
        "cwd" => cwd, "timestamp" => ts,
        "message" => { "id" => "msg_sub", "model" => "claude-haiku-5-5", "role" => "assistant", "usage" => usage,
                       "content" => [ { "type" => "text", "text" => "found it" } ] } },
      { "type" => "assistant", "uuid" => "sa2", "isSidechain" => true, "agentId" => agent_id, "sessionId" => session_id,
        "cwd" => cwd, "timestamp" => ts,
        "message" => { "id" => "msg_sub", "model" => "claude-haiku-5-5", "role" => "assistant", "usage" => usage,
                       "content" => [ { "type" => "tool_use", "id" => "t1", "name" => "Read", "input" => {} } ] } }
    ]
  end

  test "imports subagent transcripts under the parent conversation" do
    Dir.mktmpdir do |root|
      cwd = "/Users/test/code/agents"
      sid = "44444444-4444-4444-4444-444444444444"
      write_session(root, cwd, sid, basic_records(cwd, sid))
      write_subagent(root, cwd, sid, "abc123", subagent_records(cwd, sid, "abc123"),
                     meta: { "agentType" => "Explore", "description" => "Find the thing", "toolUseId" => "toolu_1" })

      summary = ClaudeHistory::Importer.run(root: root, logger: Logger.new(IO::NULL))
      assert_equal 1, summary.subagents
      assert_equal 0, summary.errors

      conv = Conversation.find_by(session_id: sid)
      sub = conv.subagents.sole
      assert_equal [ "abc123", "Explore", "Find the thing", "toolu_1", 3 ],
                   [ sub.agent_id, sub.agent_type, sub.description, sub.tool_use_id, sub.message_count ]
      assert_equal 3, sub.messages.count
      assert_equal [ nil, 50 ], sub.messages.where(record_type: "assistant").map(&:output_tokens)
      assert_equal 3, conv.messages.count, "main-thread association excludes subagent messages"

      # Re-importing the parent session must not wipe subagent messages.
      FileUtils.touch(Dir.glob(File.join(root, "*", "#{sid}.jsonl")).first, mtime: Time.now + 60)
      summary = ClaudeHistory::Importer.run(root: root, logger: Logger.new(IO::NULL))
      assert_equal 1, summary.updated
      assert_equal 0, summary.subagents, "unchanged subagent file is skipped"
      assert_equal 3, sub.messages.count
    end
  end

  test "skips subagents whose parent conversation is trashed" do
    Dir.mktmpdir do |root|
      cwd = "/Users/test/code/agents"
      sid = "55555555-5555-5555-5555-555555555555"
      write_session(root, cwd, sid, basic_records(cwd, sid))
      ClaudeHistory::Importer.run(root: root, logger: Logger.new(IO::NULL))
      Conversation.find_by(session_id: sid).soft_delete!

      write_subagent(root, cwd, sid, "def456", subagent_records(cwd, sid, "def456"))
      summary = ClaudeHistory::Importer.run(root: root, logger: Logger.new(IO::NULL))
      assert_equal 0, summary.subagents
      assert_equal 0, Subagent.count
    end
  end
end
