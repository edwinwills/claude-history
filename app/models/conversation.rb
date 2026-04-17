class Conversation < ApplicationRecord
  belongs_to :project
  has_many :messages, -> { order(:position) }, dependent: :destroy

  validates :session_id, presence: true, uniqueness: true
  validates :file_path, presence: true, uniqueness: true

  scope :recent, -> { order(last_activity_at: :desc) }

  def resume_command
    "cd #{Shellwords.escape(cwd.to_s)} && claude --resume #{session_id}"
  end

  def display_title
    return title if title.present?
    return slug.to_s.tr("-", " ").capitalize if slug.present?
    "(untitled session #{session_id[0, 8]})"
  end

  def display_messages
    messages.where(record_type: %w[user assistant])
  end
end
