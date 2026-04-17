class LabelsController < ApplicationController
  def index
    @labels = Label.alphabetical
    @new_label = Label.new(color: Label::DEFAULT_COLOR)
  end

  def create
    @label = Label.new(label_params)
    @label.color = Label::DEFAULT_COLOR if @label.color.blank?
    if @label.save
      redirect_to labels_path, notice: "Label '#{@label.name}' created."
    else
      redirect_to labels_path, alert: @label.errors.full_messages.to_sentence
    end
  end

  def update
    @label = Label.find(params[:id])
    @label.update!(label_params)
    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          "label_row_#{@label.id}",
          partial: "labels/row",
          locals: { label: @label }
        )
      }
      format.html { redirect_to labels_path }
    end
  end

  def destroy
    @label = Label.find(params[:id])
    name = @label.name
    @label.destroy!
    redirect_to labels_path, notice: "Label '#{name}' deleted."
  end

  private

  def label_params
    params.require(:label).permit(:name, :color)
  end
end
