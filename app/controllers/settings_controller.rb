class SettingsController < ApplicationController
  def show
    @setting = Setting.instance
    @source = Setting.source_of_session_key
  end

  def update
    @setting = Setting.instance
    @setting.update!(setting_params)
    redirect_to setting_path, notice: "Settings saved."
  end

  def destroy
    Setting.instance.update!(claude_ai_session_key: nil)
    redirect_to setting_path, notice: "Session key cleared."
  end

  private

  def setting_params
    params.require(:setting).permit(:claude_ai_session_key, :claude_ai_user_agent).transform_values do |v|
      v.is_a?(String) ? v.strip : v
    end
  end
end
