class ProjectsController < ApplicationController
  def index
    @projects = Project.recent.includes(:conversations)
    @total_conversations = Conversation.count
  end

  def show
    @project = Project.find(params[:id])
    @conversations = @project.conversations.recent
  end
end
