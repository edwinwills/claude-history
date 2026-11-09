class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :subagent, optional: true

  scope :main_thread, -> { where(subagent_id: nil) }

  scope :ordered, -> { order(:position) }

  def parsed_raw
    @parsed_raw ||= raw.present? ? JSON.parse(raw) : {}
  rescue JSON::ParserError
    {}
  end

  def content_blocks
    blocks = parsed_raw.dig("message", "content")
    case blocks
    when Array then blocks
    when String then [ { "type" => "text", "text" => blocks } ]
    else []
    end
  end
end
