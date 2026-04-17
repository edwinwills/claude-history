class ConversationsController < ApplicationController
  def show
    @conversation = Conversation.find(params[:id])
    @project = @conversation.project
    @messages = @conversation.display_messages.ordered
  end
end
