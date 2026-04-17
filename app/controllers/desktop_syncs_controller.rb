class DesktopSyncsController < ApplicationController
  def create
    session_key = Setting.claude_ai_session_key.to_s.strip
    if session_key.empty?
      redirect_to(setting_path,
                  alert: "Add your claude.ai sessionKey cookie in Settings before syncing desktop.")
      return
    end

    summary = ClaudeDesktop::Importer.run(session_key: session_key)
    flash[:notice] = "Desktop sync complete: #{summary}"
    redirect_to request.referer.presence || root_path
  rescue ClaudeDesktop::Client::ChallengedError => e
    redirect_to(setting_path, alert: e.message)
  rescue ClaudeDesktop::Client::AuthError => e
    redirect_to(setting_path, alert: e.message)
  rescue ClaudeDesktop::Client::NetworkError => e
    redirect_to(request.referer.presence || root_path, alert: "Desktop sync network error: #{e.message}")
  rescue ClaudeDesktop::Client::Error => e
    redirect_to(request.referer.presence || root_path, alert: "Desktop sync failed: #{e.message}")
  end
end
