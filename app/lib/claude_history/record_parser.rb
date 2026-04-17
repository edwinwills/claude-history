module ClaudeHistory
  module RecordParser
    MAX_BLOCK_TEXT = 2000

    module_function

    def extract_text(record)
      type = record["type"]
      case type
      when "user", "assistant"
        flatten_content(record.dig("message", "content"))
      when "system"
        record["subtype"].to_s
      else
        ""
      end
    end

    def role_for(record)
      case record["type"]
      when "user", "assistant" then record["type"]
      else nil
      end
    end

    def flatten_content(content)
      case content
      when String
        truncate(content)
      when Array
        content.filter_map { |block| flatten_block(block) }.reject(&:empty?).join("\n\n")
      else
        ""
      end
    end

    def flatten_block(block)
      return "" unless block.is_a?(Hash)

      case block["type"]
      when "text"
        truncate(block["text"].to_s)
      when "tool_use"
        name = block["name"]
        input_preview = truncate(block["input"].to_json.to_s, 400)
        "[tool_use: #{name}] #{input_preview}"
      when "tool_result"
        inner = block["content"]
        "[tool_result] #{flatten_content(inner)}"
      when "thinking"
        truncate(block["thinking"].to_s)
      else
        ""
      end
    end

    def truncate(str, limit = MAX_BLOCK_TEXT)
      return "" if str.nil?
      s = str.to_s
      s.length > limit ? s[0, limit] + "…" : s
    end
  end
end
