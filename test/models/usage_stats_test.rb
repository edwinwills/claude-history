require "test_helper"

class UsageStatsTest < ActiveSupport::TestCase
  setup do
    @now = Time.zone.parse("2026-11-09 12:00")
    @conv = make_conversation
    @position = 0
  end

  def add_usage(conv: @conv, at:, model: "claude-opus-5-5", input: 1, output: 10, cache_write: 100, cache_read: 1000, tools: [])
    content = [ { "type" => "text", "text" => "x" } ] + tools.map { |t| { "type" => "tool_use", "name" => t, "input" => {} } }
    Message.create!(conversation: conv, record_type: "assistant", role: "assistant", position: (@position += 1),
                    timestamp: at, model: model, api_message_id: "msg_#{@position}",
                    input_tokens: input, output_tokens: output, cache_creation_tokens: cache_write, cache_read_tokens: cache_read,
                    raw: { "type" => "assistant", "message" => { "content" => content } }.to_json, text_content: "x")
  end

  def add_user(text, at:, conv: @conv)
    Message.create!(conversation: conv, record_type: "user", role: "user", position: (@position += 1),
                    timestamp: at, text_content: text, raw: "{}")
  end

  test "sums tokens within the window and compares to the previous one" do
    add_usage(at: @now - 2.hours, output: 10)
    add_usage(at: @now - 3.hours, output: 20, model: "claude-sonnet-5-5")
    add_usage(at: @now - 30.hours, output: 5)  # previous day
    add_usage(at: @now - 3.days, output: 999)  # outside both

    stats = UsageStats.new(period: "day", now: @now)
    assert_equal 2, stats.totals.calls
    assert_equal 30, stats.totals.output_tokens
    assert_equal 2 * 1101 + 30, stats.totals.total_tokens
    assert_equal 5, stats.previous_totals.output_tokens
    assert_in_delta 2000.0 / 2202, stats.totals.cache_hit_rate, 0.0001
    assert_equal %w[claude-opus-5-5 claude-sonnet-5-5].sort, stats.by_model.map { |r| r[:model] }.sort
  end

  test "excludes trashed conversations" do
    trashed = make_conversation
    add_usage(conv: trashed, at: @now - 1.hour)
    trashed.soft_delete!

    assert_equal 0, UsageStats.new(period: "day", now: @now).totals.calls
  end

  test "buckets by hour for day and by day for month" do
    add_usage(at: @now - 90.minutes, output: 7)
    day = UsageStats.new(period: "day", now: @now)
    assert_equal 25, day.buckets.size
    assert_equal 7, day.buckets.find { |b| b.starts_at == (@now - 2.hours) }.output_tokens

    month = UsageStats.new(period: "month", now: @now)
    assert_equal 31, month.buckets.size
    assert_equal 7, month.buckets.last.output_tokens
  end

  test "counts sessions, prompts, and tool calls" do
    other = make_conversation
    add_user("please help", at: @now - 1.hour)
    add_user("[tool_result] ok", at: @now - 1.hour)
    add_usage(at: @now - 1.hour, tools: %w[Bash Read])
    add_usage(conv: other, at: @now - 1.hour, tools: %w[Bash])

    stats = UsageStats.new(period: "day", now: @now)
    assert_equal 2, stats.sessions_count
    assert_equal 1, stats.prompts_count
    assert_equal({ "Bash" => 2, "Read" => 1 }, stats.top_tools)
  end

  test "unknown period falls back to week" do
    assert_equal "week", UsageStats.new(period: "decade").period
  end

  def add_spawn(at:, conv: @conv, type: nil, background: nil)
    input = { "description" => "d", "prompt" => "p" }
    input["subagent_type"] = type if type
    input["run_in_background"] = background unless background.nil?
    Message.create!(conversation: conv, record_type: "assistant", role: "assistant", position: (@position += 1),
                    timestamp: at, raw: { "message" => { "content" => [ { "type" => "tool_use", "name" => "Agent", "input" => input } ] } }.to_json)
  end

  test "counts subagent spawns by type, background and session" do
    other = make_conversation
    add_spawn(at: @now - 1.hour, type: "Explore")
    add_spawn(at: @now - 1.hour, type: "Explore", background: true)
    add_spawn(at: @now - 2.hours, conv: other)
    add_spawn(at: @now - 30.hours)

    stats = UsageStats.new(period: "day", now: @now)
    assert_equal 3, stats.spawn_count
    assert_equal 1, stats.previous_spawn_count
    assert_equal 1, stats.background_spawn_count
    assert_equal [ [ "Explore", 2 ], [ "general-purpose", 1 ] ], stats.spawns_by_type
    assert_equal 2, stats.sessions_with_spawns_count
    assert_equal [ @conv.id, other.id ], stats.top_spawning_conversations.map { |r| r[:conversation].id }
  end

  test "splits subagent token usage from the main thread" do
    sub = Subagent.create!(conversation: @conv, agent_id: "a1", agent_type: "Explore", file_path: "/tmp/a1.jsonl")
    add_usage(at: @now - 1.hour, output: 10)
    m = add_usage(at: @now - 1.hour, output: 30)
    m.update!(subagent_id: sub.id)
    Message.create!(conversation: @conv, subagent: sub, record_type: "user", role: "user", position: (@position += 1),
                    timestamp: @now - 1.hour, text_content: "subagent prompt", raw: "{}")

    stats = UsageStats.new(period: "day", now: @now)
    assert_equal 40, stats.totals.output_tokens
    assert_equal 30, stats.subagent_totals.output_tokens
    assert_in_delta 1131.0 / 2242, stats.subagent_token_share, 0.0001
    assert_equal [ "Explore" ], stats.subagent_usage_by_type.map { |r| r[:agent_type] }
    assert_equal 0, stats.prompts_count, "subagent prompts aren't counted as user prompts"
  end

  test "tool queries tolerate string content" do
    add_user("plain string content", at: @now - 1.hour)
    Message.create!(conversation: @conv, record_type: "assistant", role: "assistant", position: (@position += 1),
                    timestamp: @now - 1.hour, raw: { "message" => { "content" => "just a string" } }.to_json)
    stats = UsageStats.new(period: "day", now: @now)
    assert_equal({}, stats.top_tools)
    assert_equal 0, stats.spawn_count
  end
end
