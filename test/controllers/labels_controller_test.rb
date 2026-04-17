require "test_helper"

class LabelsControllerTest < ActionDispatch::IntegrationTest
  test "index renders with existing labels" do
    Label.find_or_create_by_name!("plan")
    Label.find_or_create_by_name!("bug")
    get labels_path
    assert_response :success
    assert_match "plan", response.body
    assert_match "bug", response.body
  end

  test "create persists with default color" do
    assert_difference -> { Label.count } => 1 do
      post labels_path, params: { label: { name: "fresh" } }
    end
    assert_redirected_to labels_path
    assert_equal Label::DEFAULT_COLOR, Label.find_by(name: "fresh").color
  end

  test "create rejects duplicate names case-insensitively" do
    Label.find_or_create_by_name!("dup")
    assert_no_difference -> { Label.count } do
      post labels_path, params: { label: { name: "DUP" } }
    end
    assert_redirected_to labels_path
  end

  test "update recolors via turbo_stream" do
    label = Label.find_or_create_by_name!("recolor-me")
    new_color = Label::PALETTE.last
    patch label_path(label),
          params: { label: { color: new_color } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal new_color, label.reload.color
    assert_match "label_row_#{label.id}", response.body
  end

  test "update rejects a color outside the palette" do
    label = Label.find_or_create_by_name!("pal")
    original = label.color
    patch label_path(label), params: { label: { color: "#ff00ff" } }
    assert_response :unprocessable_entity
    assert_equal original, label.reload.color
  end

  test "destroy removes the label and all its attachments" do
    label = Label.find_or_create_by_name!("doomed")
    conv = make_conversation
    conv.labels << label
    assert_difference -> { Label.count } => -1, -> { ConversationLabel.count } => -1 do
      delete label_path(label)
    end
  end
end
