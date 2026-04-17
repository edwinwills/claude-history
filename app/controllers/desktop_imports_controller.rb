class DesktopImportsController < ApplicationController
  MAX_UPLOAD_BYTES = 500.megabytes

  def index
    @imports = DesktopImport.recent.with_attached_archive.limit(50)
  end

  def create
    file = params[:archive]
    if file.blank?
      redirect_to desktop_imports_path, alert: "Choose a ZIP file to upload."
      return
    end

    if file.size.to_i > MAX_UPLOAD_BYTES
      redirect_to desktop_imports_path, alert: "Upload is too large (limit #{MAX_UPLOAD_BYTES / 1.megabyte} MB)."
      return
    end

    import = DesktopImport.create!(status: "pending")
    import.archive.attach(file)

    record = ClaudeDesktopExport::Importer.run(import: import)

    if record.failed?
      redirect_to desktop_imports_path, alert: "Import failed: #{record.error_detail}"
    else
      redirect_to desktop_imports_path, notice: "Import finished — #{record.summary_line}"
    end
  end
end
