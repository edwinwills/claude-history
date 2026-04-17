require "zip"
require "json"

module ClaudeDesktopExport
  # Imports a claude.ai data-export ZIP (stored as an Active Storage attachment
  # on DesktopImport#archive) into our DB under source="desktop".
  #
  # Expected ZIP contents (as of late 2025):
  #   conversations.json — [{ uuid, name, created_at, updated_at, chat_messages: [...] }, ...]
  #   users.json / projects.json — not used here
  #
  # Dedup is on the conversation `uuid` (stored as session_id); a row that
  # already exists is updated only when the export's updated_at is newer,
  # otherwise skipped. Soft-deleted conversations are left alone.
  class Importer
    PROJECT_PATH = "claude-desktop-export".freeze
    PROJECT_NAME = "Claude Desktop".freeze

    class InvalidExport < StandardError; end

    def self.run(import:, logger: Rails.logger)
      new(import: import, logger: logger).run
    end

    def initialize(import:, logger: Rails.logger)
      @record = import
      @logger = logger
    end

    attr_reader :record

    def run
      unless @record.archive.attached?
        @record.update!(status: "failed", error_detail: "no ZIP attached")
        return @record
      end

      conversations = @record.archive.open { |file| extract_conversations_json(file) }
      project = Project.find_or_create_by!(path: PROJECT_PATH) { |p| p.name = PROJECT_NAME }

      conversations.each do |conv|
        @record.conversations_seen += 1
        import_conversation(project, conv)
      rescue => e
        @record.error_count += 1
        @logger.warn("[ClaudeDesktopExport] conv=#{conv['uuid']}: #{e.class}: #{e.message}")
      end

      project.refresh_counters!
      @record.update!(status: "succeeded")
      @record
    rescue InvalidExport => e
      @record.update!(status: "failed", error_detail: e.message)
      @record
    rescue => e
      @record.update!(status: "failed", error_detail: "#{e.class}: #{e.message}")
      raise
    end

    private

    def extract_conversations_json(file)
      body = nil
      Zip::File.open(file.path) do |zip|
        entry = zip.glob("conversations.json").first || zip.glob("**/conversations.json").first
        raise InvalidExport, "conversations.json not found in the uploaded ZIP" if entry.nil?
        body = entry.get_input_stream.read
      end
      data = JSON.parse(body)
      raise InvalidExport, "conversations.json is not a JSON array" unless data.is_a?(Array)
      data
    rescue Zip::Error => e
      raise InvalidExport, "couldn't read ZIP (#{e.class}: #{e.message})"
    rescue JSON::ParserError => e
      raise InvalidExport, "conversations.json is not valid JSON (#{e.message})"
    end

    def import_conversation(project, data)
      session_id = data["uuid"].to_s
      return if session_id.empty?

      existing = Conversation.with_deleted.find_by(session_id: session_id)
      if existing&.deleted_at
        @record.conversations_skipped += 1
        return
      end

      remote_updated = parse_ts(data["updated_at"])
      if existing && existing.last_activity_at && remote_updated &&
         existing.last_activity_at.to_i >= remote_updated.to_i
        @record.conversations_skipped += 1
        return
      end

      messages = data["chat_messages"] || []

      ActiveRecord::Base.transaction do
        conversation = Conversation.with_deleted.find_or_initialize_by(session_id: session_id)
        conversation.project = project
        conversation.source = "desktop"
        conversation.file_path = "desktop-export:#{session_id}"
        conversation.cwd = nil
        conversation.git_branch = nil
        conversation.slug = nil
        conversation.title = data["name"].presence
        conversation.started_at = parse_ts(data["created_at"])
        conversation.last_activity_at = remote_updated
        conversation.message_count = messages.count { |m| %w[human user assistant].include?(m["sender"]) }
        is_new = conversation.new_record?
        conversation.save!

        conversation.messages.delete_all
        rows = messages.each_with_index.map { |m, i| message_attrs(conversation, m, i) }
        Message.insert_all(rows) if rows.any?

        if is_new
          @record.conversations_created += 1
        else
          @record.conversations_updated += 1
        end
      end
    end

    def message_attrs(conversation, msg, index)
      now = Time.current
      sender = msg["sender"].to_s
      role = normalize_role(sender)
      {
        conversation_id: conversation.id,
        uuid: msg["uuid"],
        parent_uuid: msg["parent_message_uuid"],
        record_type: role || "other",
        role: role,
        text_content: extract_text(msg),
        raw: synthetic_raw(msg, role).to_json,
        timestamp: parse_ts(msg["created_at"]),
        position: index,
        created_at: now,
        updated_at: now
      }
    end

    def normalize_role(sender)
      case sender
      when "human", "user" then "user"
      when "assistant" then "assistant"
      end
    end

    def synthetic_raw(msg, role)
      blocks =
        if msg["content"].is_a?(Array) && msg["content"].any?
          msg["content"].map { |b| normalize_block(b) }.compact
        elsif msg["text"].is_a?(String) && !msg["text"].empty?
          [ { "type" => "text", "text" => msg["text"] } ]
        else
          []
        end

      {
        "type" => role || "other",
        "uuid" => msg["uuid"],
        "timestamp" => msg["created_at"],
        "message" => { "role" => role, "content" => blocks }
      }
    end

    def normalize_block(block)
      case block["type"]
      when "text"
        { "type" => "text", "text" => block["text"].to_s }
      when "tool_use", "tool_result", "thinking"
        block
      else
        { "type" => "text", "text" => block.to_json }
      end
    end

    def extract_text(msg)
      if msg["content"].is_a?(Array) && msg["content"].any?
        msg["content"].filter_map do |b|
          case b["type"]
          when "text" then b["text"].to_s
          when "thinking" then b["thinking"].to_s
          when "tool_use" then "[tool_use: #{b['name']}]"
          when "tool_result" then b["content"].is_a?(String) ? b["content"] : ""
          end
        end.reject(&:empty?).join("\n\n")
      else
        msg["text"].to_s
      end
    end

    def parse_ts(value)
      return nil if value.blank?
      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
