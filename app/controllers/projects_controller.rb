class ProjectsController < ApplicationController
  SOURCE_FILTERS = %w[code desktop].freeze

  def index
    @all_labels = Label.alphabetical.includes(:conversations)
    @active_label = params[:label].presence&.then { |n| Label.where("LOWER(name) = ?", n.downcase).first }
    @active_source = SOURCE_FILTERS.include?(params[:source]) ? params[:source] : nil
    @active_view = (params[:view] == "conversations" || @active_label) ? "conversations" : "projects"

    project_scope = Project.recent
    project_scope = project_scope.public_send(@active_source) if @active_source
    @total_projects = project_scope.size
    @total_conversations = @active_source ? Conversation.where(source: @active_source).count : Conversation.count

    if @active_label
      scope = @active_label.conversations.recent.includes(:project, :labels)
      scope = scope.where(source: @active_source) if @active_source
      @labeled_conversations = scope
    elsif @active_view == "conversations"
      scope = Conversation.recent.includes(:project, :labels)
      scope = scope.where(source: @active_source) if @active_source
      @conversations = scope
    else
      @projects = project_scope
    end
  end

  def show
    @project = Project.find(params[:id])
    @conversations = @project.conversations.recent.includes(:labels)
  end

  def destroy
    @project = Project.find(params[:id])
    @project.soft_delete!
    redirect_to root_path, notice: "Moved '#{@project.name}' and #{@project.conversation_count} conversation(s) to trash."
  end

  def restore
    @project = Project.with_deleted.find(params[:id])
    @project.restore!
    redirect_to project_path(@project), notice: "Restored '#{@project.name}'."
  end
end
