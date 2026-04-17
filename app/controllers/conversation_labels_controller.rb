class ConversationLabelsController < ApplicationController
  def create
    conversation = Conversation.find(params[:conversation_id])
    label = Label.find_or_create_by_name!(params[:name])
    if label
      ConversationLabel.find_or_create_by!(conversation: conversation, label: label)
    end
    respond(conversation)
  end

  def destroy
    conversation = Conversation.find(params[:conversation_id])
    label = Label.find(params[:id])
    ConversationLabel.where(conversation: conversation, label: label).destroy_all
    respond(conversation)
  end

  private

  def respond(conversation)
    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          "conversation_labels_#{conversation.id}",
          partial: "conversations/labels",
          locals: { conversation: conversation }
        )
      }
      format.html { redirect_to conversation_path(conversation) }
    end
  end
end
