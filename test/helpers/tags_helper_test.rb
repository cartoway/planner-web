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

  test 'tag_select_option_attributes mirrors list badge data for Tom Select' do
    tag = tags(:tag_one)
    assert_equal({ 'data-default-icon' => tag.default_icon, 'data-color' => '#FF0000' }, tag_select_option_attributes(tag))
    assert_equal({ 'data-default-icon' => tags(:tag_two).default_icon, 'data-icon' => 'fa-diamond' }, tag_select_option_attributes(tags(:tag_two)))
    assert_equal({ 'data-default-icon' => tags(:tag_three).default_icon }, tag_select_option_attributes(tags(:tag_three)))
  end
end
