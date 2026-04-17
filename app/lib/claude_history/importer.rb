require "json"

module ClaudeHistory
  class Importer
    DEFAULT_ROOT = File.expand_path("~/.claude/projects")

    Summary = Struct.new(:files_seen, :created, :updated, :skipped, :errors, keyword_init: true) do
      def to_s
        "files_seen=#{files_seen} created=#{created} updated=#{updated} skipped=#{skipped} errors=#{errors}"
      end
    end

    def self.run(root: DEFAULT_ROOT, logger: Rails.logger)
      new(root: root, logger: logger).run
    end

    def initialize(root: DEFAULT_ROOT, logger: Rails.logger)
      @root = root
      @logger = logger
      @summary = Summary.new(files_seen: 0, created: 0, updated: 0, skipped: 0, errors: 0)
    end

    attr_reader :summary

    def run
      return summary unless Dir.exist?(@root)

      Dir.glob(File.join(@root, "*", "*.jsonl")).sort.each do |file|
        @summary.files_seen += 1
        import_file(file)
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

        conversation.messages.delete_all
        rows = records.each_with_index.map { |rec, i| message_attrs(conversation, rec, i) }
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

    def message_attrs(conversation, record, index)
      now = Time.current
      {
        conversation_id: conversation.id,
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
      }
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
