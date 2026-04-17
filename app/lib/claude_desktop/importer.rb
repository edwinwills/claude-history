module ClaudeDesktop
  # Imports conversations from claude.ai into our DB under source="desktop".
  #
  # Grouping: all desktop conversations live under a single synthetic Project
  # (path = "claude-desktop:<org_uuid>", name = "Claude Desktop"). claude.ai's
  # own "Projects" feature isn't mirrored in this first pass.
  class Importer
    PROJECT_PATH_PREFIX = "claude-desktop:".freeze

    Summary = Struct.new(:organizations, :conversations_seen, :created, :updated, :skipped, :errors, keyword_init: true) do
      def to_s
        "organizations=#{organizations} conversations_seen=#{conversations_seen} created=#{created} updated=#{updated} skipped=#{skipped} errors=#{errors}"
      end
    end

    def self.run(session_key: ENV["CLAUDE_AI_SESSION_KEY"], user_agent: nil, client: nil, logger: Rails.logger)
      client ||= Client.new(session_key: session_key, user_agent: user_agent, logger: logger)
      new(client: client, logger: logger).run
    end

    def initialize(client:, logger: Rails.logger)
      @client = client
      @logger = logger
      @summary = Summary.new(organizations: 0, conversations_seen: 0, created: 0, updated: 0, skipped: 0, errors: 0)
    end

    attr_reader :summary

    def run
      orgs = @client.organizations
      @summary.organizations = orgs.length

      orgs.each do |org|
        import_org(org)
      end

      Project.where("path LIKE ?", "#{PROJECT_PATH_PREFIX}%").find_each(&:refresh_counters!)
      summary
    end

    private

    def import_org(org)
      org_uuid = org["uuid"]
      project_path = "#{PROJECT_PATH_PREFIX}#{org_uuid}"
      project = Project.find_or_create_by!(path: project_path) do |p|
        p.name = org["name"].presence ? "Claude Desktop · #{org["name"]}" : "Claude Desktop"
      end

      convs = @client.conversations(org_uuid)
      convs.each do |summary|
        @summary.conversations_seen += 1
        import_conversation(project, org_uuid, summary)
      rescue => e
        @summary.errors += 1
        @logger.warn("[ClaudeDesktop::Importer] conv=#{summary['uuid']}: #{e.class}: #{e.message}")
      end
    end

    def import_conversation(project, org_uuid, summary)
      conv_uuid = summary["uuid"]
      remote_updated = parse_ts(summary["updated_at"])

      existing = Conversation.with_deleted.find_by(session_id: conv_uuid)
      if existing&.deleted_at
        @summary.skipped += 1
        return
      end

      if existing && existing.last_activity_at && remote_updated && existing.last_activity_at.to_i >= remote_updated.to_i
        @summary.skipped += 1
        return
      end

      detail = @client.conversation(org_uuid, conv_uuid)
      messages = detail["chat_messages"] || []

      ActiveRecord::Base.transaction do
        conversation = Conversation.with_deleted.find_or_initialize_by(session_id: conv_uuid)
        conversation.project = project
        conversation.source = "desktop"
        conversation.file_path = "desktop:#{conv_uuid}"
        conversation.cwd = nil
        conversation.git_branch = nil
        conversation.slug = nil
        conversation.title = detail["name"].presence || summary["name"].presence
        conversation.started_at = parse_ts(detail["created_at"] || summary["created_at"])
        conversation.last_activity_at = parse_ts(detail["updated_at"] || summary["updated_at"])
        conversation.message_count = messages.count { |m| %w[human assistant user].include?(m["sender"]) }
        conversation.save!

        conversation.messages.delete_all
        rows = messages.each_with_index.map { |m, i| message_attrs(conversation, m, i) }
        Message.insert_all(rows) if rows.any?
      end

      if existing
        @summary.updated += 1
      else
        @summary.created += 1
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
      else nil
      end
    end

    # Produce a record that the existing view layer (which assumes
    # `message.content` is an array of typed blocks) can render unchanged.
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
