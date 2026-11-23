class SessionForksController < ApplicationController
  def create
    @conversation = Conversation.find(params[:conversation_id])
    @message_uuid = params.require(:message_uuid)
    begin
      @fork = ClaudeHistory::SessionForker.call(@conversation, @message_uuid)
    rescue ClaudeHistory::SessionForker::Error => e
      @error = e.message
    end

    respond_to do |format|
      format.turbo_stream
      format.html do
        flash[@error ? :alert : :notice] = @error || @fork.resume_command
        redirect_to conversation_path(@conversation, anchor: "msg-#{@message_uuid}")
      end
    end
  end
end
