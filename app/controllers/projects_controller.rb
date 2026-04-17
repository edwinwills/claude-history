class ProjectsController < ApplicationController
  def index
    @all_labels = Label.alphabetical.includes(:conversations)
    @active_label = params[:label].presence&.then { |n| Label.where("LOWER(name) = ?", n.downcase).first }

    if @active_label
      @labeled_conversations = @active_label.conversations.recent.includes(:project, :labels)
    else
      @projects = Project.recent
      @total_conversations = Conversation.count
    end
  end

  def show
    @project = Project.find(params[:id])
    @conversations = @project.conversations.recent.includes(:labels)
  end
end
