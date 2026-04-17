require "test_helper"

class LabelTest < ActiveSupport::TestCase
  test "find_or_create_by_name! returns existing label case-insensitively" do
    l1 = Label.find_or_create_by_name!("Plan")
    l2 = Label.find_or_create_by_name!("plan")
    l3 = Label.find_or_create_by_name!(" PLAN ")
    assert_equal l1.id, l2.id
    assert_equal l1.id, l3.id
  end

  test "find_or_create_by_name! returns nil for blank input" do
    assert_nil Label.find_or_create_by_name!("   ")
    assert_nil Label.find_or_create_by_name!(nil)
  end

  test "new labels default to slate color" do
    l = Label.find_or_create_by_name!("fresh")
    assert_equal Label::DEFAULT_COLOR, l.color
    assert_includes Label::PALETTE, l.color
  end

  test "color must be in the palette" do
    l = Label.new(name: "x", color: "#ff00ff")
    assert_not l.valid?
    assert l.errors[:color].any?
  end

  test "color_with_default falls back if stored value is outside palette" do
    l = Label.find_or_create_by_name!("x")
    l.update_column(:color, "#nonsense")
    assert_equal Label::DEFAULT_COLOR, l.color_with_default
  end

  test "alphabetical scope sorts case-insensitively" do
    Label.create!(name: "Zeta", color: Label::DEFAULT_COLOR)
    Label.create!(name: "alpha", color: Label::DEFAULT_COLOR)
    Label.create!(name: "Beta", color: Label::DEFAULT_COLOR)
    assert_equal %w[alpha Beta Zeta], Label.alphabetical.pluck(:name)
  end
end
