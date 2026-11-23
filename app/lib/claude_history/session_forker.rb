require "json"

module ClaudeHistory
  # Writes a copy of a Claude Code session that ends after the turn containing
  # `message_uuid`, so `claude --resume <copy> --fork-session` continues from
  # that point. The CLI's own `--resume-session-at` only works with `-p`.
  #
  # The copy holds only the parentUuid chain leading to the cut, so metadata
  # records (last-prompt leafUuid, later branches) can't steer the resume past
  # it. Its session id is derived from the cut, so repeat requests reuse it.
  class SessionForker
    class Error < StandardError; end

    NAMESPACE = "8d6a3c52-5f0e-4b8e-9d3b-3f0c2a7e1b44".freeze

    def self.call(conversation, message_uuid)
      new(conversation, message_uuid).call
    end

    def initialize(conversation, message_uuid)
      @conversation = conversation
      @message_uuid = message_uuid.to_s
    end

    def call
      raise Error, "Only Claude Code sessions can be resumed." unless @conversation.code?
      source = @conversation.file_path
      raise Error, "Session file not found: #{source}" unless File.file?(source)

      records = load_records(source)
      start = records.index { |r| r["uuid"] == @message_uuid }
      raise Error, "Message not found in the session file (try syncing)." unless start

      cut = records[turn_end(records, start)]
      session_id = Digest::UUID.uuid_v5(NAMESPACE, "#{@conversation.session_id}/#{cut['uuid']}")
      path = File.join(File.dirname(source), "#{session_id}.jsonl")

      SessionFork.find_or_create_by!(session_id: session_id) do |fork|
        fork.conversation = @conversation
        fork.message_uuid = cut["uuid"]
        fork.file_path = path
      end.tap { write(path, chain_to(records, cut), session_id) unless File.exist?(path) }
    end

    private

    def load_records(file)
      File.foreach(file).filter_map do |line|
        JSON.parse(line) unless line.strip.empty?
      rescue JSON::ParserError
        nil
      end
    end

    # Index of the last record that descends from records[start] before the
    # next human prompt, so the copy never ends mid-turn (e.g. on a tool_use
    # with no tool_result).
    def turn_end(records, start)
      included = Set[records[start]["uuid"]]
      cut = start
      records.each_with_index.drop(start + 1).each do |record, i|
        next unless record["uuid"] && included.include?(record["parentUuid"])
        break if human_prompt?(record)
        included << record["uuid"]
        cut = i
      end
      cut
    end

    def human_prompt?(record)
      return false unless record["type"] == "user"
      return false if record["isMeta"] || record["isCompactSummary"] || record["toolUseResult"]
      content = record.dig("message", "content")
      !(content.is_a?(Array) && content.any? { |b| b.is_a?(Hash) && b["type"] == "tool_result" })
    end

    # The cut record and its ancestors, in file order. Stops where parentUuid
    # is null, which is also where Claude Code stops (e.g. a compact boundary).
    def chain_to(records, cut)
      by_uuid = records.select { |r| r["uuid"] }.index_by { |r| r["uuid"] }
      chain = []
      seen = Set.new
      node = cut
      while node && seen.add?(node["uuid"])
        chain << node
        node = by_uuid[node["parentUuid"]]
      end
      chain.reverse
    end

    def write(path, chain, session_id)
      tmp = "#{path}.tmp-#{Process.pid}"
      File.open(tmp, "w") do |f|
        chain.each do |record|
          record = record.merge("sessionId" => session_id)
          record["session_id"] = session_id if record.key?("session_id")
          f.puts(record.to_json)
        end
      end
      File.rename(tmp, path)
    ensure
      File.delete(tmp) if tmp && File.exist?(tmp)
    end
  end
end
