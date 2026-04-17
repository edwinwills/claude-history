class Setting < ApplicationRecord
  # Singleton: always operate on the first (and only) row.
  def self.instance
    first || create!
  end

  def self.claude_ai_session_key
    instance.claude_ai_session_key.presence || ENV["CLAUDE_AI_SESSION_KEY"].presence
  end

  def self.source_of_session_key
    if instance.claude_ai_session_key.present?
      :database
    elsif ENV["CLAUDE_AI_SESSION_KEY"].present?
      :env
    else
      :none
    end
  end
end
