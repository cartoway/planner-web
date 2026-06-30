require 'test_helper'

class TagsHelperTest < ActionView::TestCase
  include TagsHelper

  test 'tag_list_badge_customized? is false when color and icon are blank' do
    tag = tags(:tag_one)
    tag.color = nil
    tag.icon = nil

    assert_not tag_list_badge_customized?(tag)
  end

  test 'tag_list_badge_customized? is true when color or icon is set' do
    assert tag_list_badge_customized?(tags(:tag_one))
    assert tag_list_badge_customized?(tags(:tag_two))
  end

  test 'tag_list_badge_icon_style returns color only when customized' do
    assert_equal 'color: #FF0000', tag_list_badge_icon_style(tags(:tag_one))
    assert_nil tag_list_badge_icon_style(tags(:tag_two))
  end
end
