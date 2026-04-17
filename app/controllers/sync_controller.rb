class SyncController < ApplicationController
  def create
    summary = ClaudeHistory::Importer.run
    flash[:notice] = "Sync complete: #{summary}"
    redirect_to request.referer.presence || root_path
  end
end
