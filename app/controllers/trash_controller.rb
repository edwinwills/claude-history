class TrashController < ApplicationController
  def index
    @deleted_projects = Project.deleted.order(deleted_at: :desc)
    @deleted_conversations = Conversation.deleted
      .joins(:project).where(projects: { deleted_at: nil })
      .includes(:project, :labels)
      .order(deleted_at: :desc)
  end
end
