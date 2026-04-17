class DesktopImport < ApplicationRecord
  STATUSES = %w[pending succeeded failed].freeze

  has_one_attached :archive

  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }

  def succeeded?
    status == "succeeded"
  end

  def failed?
    status == "failed"
  end

  def filename
    archive.attached? ? archive.filename.to_s : nil
  end

  def byte_size
    archive.attached? ? archive.byte_size : nil
  end

  def summary_line
    "seen=#{conversations_seen} created=#{conversations_created} updated=#{conversations_updated} " \
      "skipped=#{conversations_skipped} errors=#{error_count}"
  end
end
