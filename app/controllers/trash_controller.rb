class TrashController < ApplicationController
  def index
    @conversations = Conversation.deleted.includes(:project, :labels).order(deleted_at: :desc)
  end
end
