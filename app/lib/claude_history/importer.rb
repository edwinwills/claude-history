require "json"

module ClaudeHistory
  class Importer
    DEFAULT_ROOT = File.expand_path("~/.claude/projects")

    Summary = Struct.new(:files_seen, :created, :updated, :skipped, :errors, :subagents, keyword_init: true) do
      def to_s
        "files_seen=#{files_seen} created=#{created} updated=#{updated} skipped=#{skipped} " \
          "subagents=#{subagents} errors=#{errors}"
      end
    end

    def self.run(root: DEFAULT_ROOT, logger: Rails.logger)
      new(root: root, logger: logger).run
    end

    def initialize(root: DEFAULT_ROOT, logger: Rails.logger)
      @root = root
      @logger = logger
      @summary = Summary.new(files_seen: 0, created: 0, updated: 0, skipped: 0, errors: 0, subagents: 0)
    end

    attr_reader :summary

    def run
      return summary unless Dir.exist?(@root)

      Dir.glob(File.join(@root, "*", "*.jsonl")).sort.each do |file|
        @summary.files_seen += 1
        import_file(file)
      end

      # Subagent transcripts: <project>/<session_id>/subagents/agent-<id>.jsonl.
      # Run after sessions so the parent conversation exists.
      Dir.glob(File.join(@root, "*", "*", "subagents", "agent-*.jsonl")).sort.each do |file|
        import_subagent_file(file)
      end

      Project.find_each(&:refresh_counters!)
      summary
    end

    private

    def import_file(file)
      session_id = File.basename(file, ".jsonl")
      mtime = File.mtime(file)

      existing = Conversation.with_deleted.find_by(session_id: session_id)
      if existing&.deleted_at
        @summary.skipped += 1
        return
      end
      if existing && existing.file_mtime && existing.file_path == file && existing.file_mtime.to_i >= mtime.to_i
        @summary.skipped += 1
        return
      end

      records = load_records(file)
      if records.empty?
        @summary.skipped += 1
        return
      end

      cwd = records.find { |r| r["cwd"].present? }&.dig("cwd") || infer_cwd_from_path(file)
      project = Project.find_or_create_for_cwd(cwd)

      ActiveRecord::Base.transaction do
        conversation = Conversation.with_deleted.find_or_initialize_by(session_id: session_id)
        conversation.project = project
        conversation.file_path = file
        conversation.file_mtime = mtime
        conversation.file_size = File.size(file)
        conversation.cwd = cwd
        apply_aggregates(conversation, records)
        conversation.save!

        conversation.messages.delete_all # main thread only; subagent rows are kept
        rows = records.each_with_index.map { |rec, i| message_attrs(conversation, rec, i) }
        dedupe_usage!(rows)
        Message.insert_all(rows) if rows.any?
      end

      if existing
        @summary.updated += 1
      else
        @summary.created += 1
      end
    rescue => e
      @summary.errors += 1
      @logger.warn("[ClaudeHistory::Importer] #{file}: #{e.class}: #{e.message}")
    end

    def import_subagent_file(file)
      session_id = File.basename(File.dirname(file, 2))
      # Parent missing, or soft-deleted (default scope hides it): skip.
      conversation = Conversation.find_by(session_id: session_id)
      return unless conversation

      mtime = File.mtime(file)
      subagent = conversation.subagents.find_or_initialize_by(file_path: file)
      return if subagent.persisted? && subagent.file_mtime && subagent.file_mtime.to_i >= mtime.to_i

      records = load_records(file)
      return if records.empty?

      meta = load_meta(file.sub(/\.jsonl\z/, ".meta.json"))
      timestamps = records.filter_map { |r| parse_ts(r["timestamp"]) }

      ActiveRecord::Base.transaction do
        subagent.agent_id = records.find { |r| r["agentId"].present? }&.dig("agentId") ||
                            File.basename(file, ".jsonl").delete_prefix("agent-")
        subagent.agent_type = meta["agentType"]
        subagent.description = meta["description"]
        subagent.tool_use_id = meta["toolUseId"]
        subagent.file_mtime = mtime
        subagent.file_size = File.size(file)
        subagent.started_at = timestamps.min
        subagent.last_activity_at = timestamps.max
        subagent.message_count = records.count { |r| %w[user assistant].include?(r["type"]) }
        subagent.save!

        subagent.messages.delete_all
        rows = records.each_with_index.map { |rec, i| message_attrs(conversation, rec, i, subagent_id: subagent.id) }
        dedupe_usage!(rows)
        Message.insert_all(rows) if rows.any?
      end
      @summary.subagents += 1
    rescue => e
      @summary.errors += 1
      @logger.warn("[ClaudeHistory::Importer] #{file}: #{e.class}: #{e.message}")
    end

    def load_meta(path)
      File.exist?(path) ? JSON.parse(File.read(path)) : {}
    rescue JSON::ParserError
      {}
    end

    def load_records(file)
      records = []
      File.foreach(file) do |line|
        line = line.strip
        next if line.empty?
        begin
          records << JSON.parse(line)
        rescue JSON::ParserError
          # skip malformed lines
        end
      end
      records
    end

    def apply_aggregates(conversation, records)
      first_ts = records.filter_map { |r| parse_ts(r["timestamp"]) }.min
      last_ts  = records.filter_map { |r| parse_ts(r["timestamp"]) }.max
      slug = records.find { |r| r["slug"].present? }&.dig("slug")
      branch = records.reverse.find { |r| r["gitBranch"].present? }&.dig("gitBranch")
      message_count = records.count { |r| %w[user assistant].include?(r["type"]) }
      title = derive_title(records, slug)

      conversation.started_at = first_ts
      conversation.last_activity_at = last_ts
      conversation.slug = slug
      conversation.git_branch = branch
      conversation.message_count = message_count
      conversation.title = title
    end

    def derive_title(records, slug)
      if slug.present?
        return slug.tr("-", " ").split.map(&:capitalize).join(" ")
      end

      first_user = records.find { |r| r["type"] == "user" }
      return nil unless first_user

      text = ClaudeHistory::RecordParser.flatten_content(first_user.dig("message", "content"))
      text = text.to_s.strip.gsub(/\s+/, " ")
      return nil if text.empty?
      text.length > 80 ? text[0, 80] + "…" : text
    end

    def message_attrs(conversation, record, index, subagent_id: nil)
      now = Time.current
      {
        conversation_id: conversation.id,
        subagent_id: subagent_id,
        uuid: record["uuid"],
        parent_uuid: record["parentUuid"],
        record_type: record["type"].to_s,
        role: ClaudeHistory::RecordParser.role_for(record),
        text_content: ClaudeHistory::RecordParser.extract_text(record),
        raw: record.to_json,
        timestamp: parse_ts(record["timestamp"]),
        position: index,
        created_at: now,
        updated_at: now
      }.merge(usage_attrs(record))
    end

    def usage_attrs(record)
      return USAGE_BLANK unless record["type"] == "assistant"

      message = record["message"].is_a?(Hash) ? record["message"] : {}
      usage = message["usage"].is_a?(Hash) ? message["usage"] : {}
      model = message["model"].presence
      {
        model: model == "<synthetic>" ? nil : model,
        api_message_id: message["id"].presence,
        input_tokens: usage["input_tokens"],
        output_tokens: usage["output_tokens"],
        cache_creation_tokens: usage["cache_creation_input_tokens"],
        cache_read_tokens: usage["cache_read_input_tokens"]
      }
    end

    USAGE_BLANK = {
      model: nil, api_message_id: nil, input_tokens: nil, output_tokens: nil,
      cache_creation_tokens: nil, cache_read_tokens: nil
    }.freeze
    USAGE_TOKEN_KEYS = %i[input_tokens output_tokens cache_creation_tokens cache_read_tokens].freeze

    # Claude Code writes one record per content block of an API response, each
    # repeating that response's usage. Keep usage only on the last one so sums
    # aren't inflated.
    def dedupe_usage!(rows)
      seen = Set.new
      rows.reverse_each do |row|
        id = row[:api_message_id]
        next if id.nil?
        if seen.include?(id)
          USAGE_TOKEN_KEYS.each { |k| row[k] = nil }
        else
          seen << id
        end
      end
    end

    def parse_ts(value)
      return nil if value.blank?
      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def infer_cwd_from_path(file)
      dir = File.basename(File.dirname(file))
      "/" + dir.sub(/\A-/, "").tr("-", "/")
    end
  end
end
