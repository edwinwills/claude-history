class SubagentsController < ApplicationController
  def show
    @conversation = Conversation.find(params[:conversation_id])
    @subagent = @conversation.subagents.find(params[:id])
    @project = @conversation.project
    @messages = @subagent.display_messages
    @tokens = Message.where(subagent_id: @subagent.id).sum(Arel.sql(UsageStats::TOTAL_SQL))
  end
end
