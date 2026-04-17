class ConversationsController < ApplicationController
  TITLE_VARIANTS = %w[heading inline].freeze

  def show
    @conversation = Conversation.find(params[:id])
    @project = @conversation.project
    @messages = @conversation.display_messages.ordered
  end

  def title
    conversation = Conversation.find(params[:id])
    render partial: "conversations/title",
           layout: false,
           locals: {
             conversation: conversation,
             editing: params[:editing].present?,
             variant: title_variant
           }
  end

  def update
    @conversation = Conversation.find(params[:id])
    @conversation.update!(conversation_params)
    variant = title_variant
    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          "conversation_title_#{variant}_#{@conversation.id}",
          partial: "conversations/title",
          locals: { conversation: @conversation, editing: false, variant: variant }
        )
      }
      format.html {
        redirect_to(variant == :inline ? project_path(@conversation.project) : conversation_path(@conversation))
      }
    end
  end

  def destroy
    @conversation = Conversation.find(params[:id])
    @conversation.soft_delete!
    redirect_to project_path(@conversation.project), notice: "Conversation moved to trash."
  end

  def restore
    @conversation = Conversation.with_deleted.find(params[:id])
    @conversation.restore!
    redirect_to conversation_path(@conversation), notice: "Conversation restored."
  end

  private

  def title_variant
    v = params[:variant].to_s
    TITLE_VARIANTS.include?(v) ? v.to_sym : :heading
  end

  def conversation_params
    params.require(:conversation).permit(:custom_title)
  end
end
