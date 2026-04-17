class Conversation < ApplicationRecord
  belongs_to :project
  has_many :messages, -> { order(:position) }, dependent: :destroy
  has_many :conversation_labels, dependent: :destroy
  has_many :labels, through: :conversation_labels

  default_scope { where(deleted_at: nil) }

  validates :session_id, presence: true, uniqueness: true
  validates :file_path, presence: true, uniqueness: true

  scope :recent, -> { order(last_activity_at: :desc) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }
  scope :deleted, -> { unscope(where: :deleted_at).where.not(deleted_at: nil) }
  scope :with_label, ->(label) { joins(:labels).where(labels: { id: label }) }
  scope :with_label_name, ->(name) {
    joins(:labels).where("LOWER(labels.name) = ?", name.to_s.downcase.strip)
  }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  def resume_command
    "cd #{Shellwords.escape(cwd.to_s)} && claude --resume #{session_id}"
  end

  def display_title
    return custom_title if custom_title.present?
    return title if title.present?
    return slug.to_s.tr("-", " ").capitalize if slug.present?
    "(untitled session #{session_id[0, 8]})"
  end

  def display_messages
    messages.where(record_type: %w[user assistant])
  end
end
