class DesktopSyncsController < ApplicationController
  def create
    session_key = ENV["CLAUDE_AI_SESSION_KEY"].to_s.strip
    if session_key.empty?
      redirect_to(request.referer.presence || root_path,
                  alert: "Set CLAUDE_AI_SESSION_KEY to your claude.ai sessionKey cookie before syncing desktop.")
      return
    end

    summary = ClaudeDesktop::Importer.run(session_key: session_key)
    flash[:notice] = "Desktop sync complete: #{summary}"
    redirect_to request.referer.presence || root_path
  rescue ClaudeDesktop::Client::AuthError => e
    redirect_to(request.referer.presence || root_path, alert: e.message)
  rescue ClaudeDesktop::Client::Error => e
    redirect_to(request.referer.presence || root_path, alert: "Desktop sync failed: #{e.message}")
  end
end
