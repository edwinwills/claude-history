# Aggregates token usage, model mix and activity over a rolling window.
#
# Token figures come from Claude Code assistant records only (desktop exports
# carry no usage data). Usage lives on one row per API response — see
# ClaudeHistory::Importer#dedupe_usage! — so plain SUMs are safe.
class UsageStats
  PERIODS = {
    "day"   => { length: 1.day,   bucket: :hour, label: "Last 24 hours" },
    "week"  => { length: 7.days,  bucket: :day,  label: "Last 7 days" },
    "month" => { length: 30.days, bucket: :day,  label: "Last 30 days" }
  }.freeze
  DEFAULT_PERIOD = "week".freeze

  TOKEN_COLUMNS = %i[input_tokens output_tokens cache_creation_tokens cache_read_tokens].freeze
  TOTAL_SQL = "COALESCE(messages.input_tokens,0) + COALESCE(messages.output_tokens,0) + " \
              "COALESCE(messages.cache_creation_tokens,0) + COALESCE(messages.cache_read_tokens,0)".freeze

  Totals = Struct.new(:calls, :input_tokens, :output_tokens, :cache_creation_tokens, :cache_read_tokens, keyword_init: true) do
    def total_tokens
      input_tokens + output_tokens + cache_creation_tokens + cache_read_tokens
    end

    # Share of prompt tokens served from cache.
    def cache_hit_rate
      prompt = input_tokens + cache_creation_tokens + cache_read_tokens
      prompt.zero? ? nil : cache_read_tokens.to_f / prompt
    end
  end

  Bucket = Struct.new(:starts_at, :input_tokens, :output_tokens, :cache_creation_tokens, :cache_read_tokens, :calls, keyword_init: true) do
    def total_tokens
      input_tokens + output_tokens + cache_creation_tokens + cache_read_tokens
    end
  end

  attr_reader :period, :now

  def initialize(period: DEFAULT_PERIOD, now: Time.current)
    @period = PERIODS.key?(period.to_s) ? period.to_s : DEFAULT_PERIOD
    @now = now
  end

  def label = config[:label]
  def range = (now - config[:length])..now
  def previous_range = (now - 2 * config[:length])...(now - config[:length])

  def totals = @totals ||= totals_for(range)
  def previous_totals = @previous_totals ||= totals_for(previous_range)

  # Conversations (any source) with at least one message in the window.
  def sessions_count
    @sessions_count ||= messages_in(range).distinct.count(:conversation_id)
  end

  def previous_sessions_count
    @previous_sessions_count ||= messages_in(previous_range).distinct.count(:conversation_id)
  end

  # Human-typed user turns: excludes tool results that come back as user records.
  def prompts_count
    @prompts_count ||= messages_in(range)
      .where(role: "user")
      .where("messages.text_content NOT LIKE '[tool_result]%'")
      .where("messages.text_content <> ''")
      .count
  end

  def projects_count
    @projects_count ||= messages_in(range).distinct.count("conversations.project_id")
  end

  def by_model
    @by_model ||= grouped(usage_in(range).where.not(model: nil), "messages.model")
      .map { |key, totals| { model: key, totals: totals } }
  end

  def top_projects(limit: 8)
    rows = grouped(usage_in(range), "conversations.project_id").first(limit)
    projects = Project.where(id: rows.map(&:first)).index_by(&:id)
    rows.map { |id, totals| { project: projects[id], totals: totals } }
  end

  def top_conversations(limit: 8)
    rows = grouped(usage_in(range), "messages.conversation_id").first(limit)
    conversations = Conversation.where(id: rows.map(&:first)).includes(:project).index_by(&:id)
    rows.filter_map { |id, totals| conversations[id] && { conversation: conversations[id], totals: totals } }
  end

  def top_tools(limit: 12)
    @top_tools ||= messages_in(range)
      .where(record_type: "assistant")
      .joins("JOIN json_each(messages.raw, '$.message.content') AS block")
      .where("json_extract(block.value, '$.type') = 'tool_use'")
      .group("json_extract(block.value, '$.name')")
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(limit)
      .count
  end

  def buckets
    @buckets ||= begin
      step = config[:bucket] == :hour ? 1.hour : 1.day
      first = config[:bucket] == :hour ? range.begin.beginning_of_hour : range.begin.beginning_of_day
      starts = []
      t = first
      while t <= now
        starts << t
        t += step
      end
      by_start = starts.index_with do |s|
        Bucket.new(starts_at: s, calls: 0, **TOKEN_COLUMNS.index_with(0))
      end

      usage_in(range).pluck(:timestamp, *TOKEN_COLUMNS).each do |ts, *tokens|
        key = config[:bucket] == :hour ? ts.in_time_zone.beginning_of_hour : ts.in_time_zone.beginning_of_day
        bucket = by_start[key] or next
        bucket.calls += 1
        TOKEN_COLUMNS.each_with_index { |col, i| bucket[col] += tokens[i].to_i }
      end
      by_start.values
    end
  end

  def bucket_format
    config[:bucket] == :hour ? "%H:%M" : "%a %d %b"
  end

  def self.percent_change(current, previous)
    return nil if previous.to_f.zero?
    (current - previous).to_f / previous * 100
  end

  private

  def config = PERIODS.fetch(period)

  # All live messages (not in trashed conversations/projects) within a window.
  def messages_in(window)
    Message
      .joins(conversation: :project)
      .where(conversations: { deleted_at: nil }, projects: { deleted_at: nil })
      .where(timestamp: window)
  end

  # Rows that carry API usage (one per assistant response).
  def usage_in(window)
    messages_in(window).where.not(output_tokens: nil)
  end

  def totals_for(window)
    row = usage_in(window).pick(
      Arel.sql("COUNT(*)"),
      *TOKEN_COLUMNS.map { |c| Arel.sql("COALESCE(SUM(messages.#{c}),0)") }
    )
    Totals.new(calls: row[0].to_i, **TOKEN_COLUMNS.each_with_index.to_h { |c, i| [ c, row[i + 1].to_i ] })
  end

  # Returns [[group_key, Totals], ...] ordered by total tokens desc.
  def grouped(scope, column)
    scope
      .group(Arel.sql(column))
      .order(Arel.sql("SUM(#{TOTAL_SQL}) DESC"))
      .pluck(Arel.sql(column), Arel.sql("COUNT(*)"), *TOKEN_COLUMNS.map { |c| Arel.sql("COALESCE(SUM(messages.#{c}),0)") })
      .map do |key, calls, *sums|
        [ key, Totals.new(calls: calls.to_i, **TOKEN_COLUMNS.each_with_index.to_h { |c, i| [ c, sums[i].to_i ] }) ]
      end
  end
end
