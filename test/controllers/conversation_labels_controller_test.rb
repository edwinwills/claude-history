require "test_helper"

class ConversationLabelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @conversation = make_conversation
  end

  test "create finds-or-creates label by name and attaches" do
    assert_difference -> { Label.count } => 1, -> { @conversation.labels.count } => 1 do
      post conversation_labels_path(@conversation), params: { name: "planning" }
    end
    assert_equal "planning", Label.last.name
  end

  test "create does not duplicate an existing label" do
    Label.find_or_create_by_name!("existing")
    assert_difference -> { Label.count } => 0, -> { @conversation.labels.count } => 1 do
      post conversation_labels_path(@conversation), params: { name: "existing" }
    end
  end

  test "create with blank name is a no-op" do
    assert_no_difference [ "Label.count", "@conversation.labels.count" ] do
      post conversation_labels_path(@conversation), params: { name: "   " }
    end
  end

  test "destroy removes the attachment but keeps the label row" do
    label = Label.find_or_create_by_name!("detach-me")
    @conversation.labels << label
    assert_difference -> { @conversation.labels.count } => -1, -> { Label.count } => 0 do
      delete conversation_label_path(@conversation, label)
    end
  end
end
