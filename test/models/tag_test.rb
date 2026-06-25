require 'test_helper'

class TagTest < ActiveSupport::TestCase

  setup do
    @customer = customers(:customer_one)
  end

  test 'should not save' do
    tag = @customer.tags.build
    assert_not tag.save, 'Saved without required fields'
  end

  test 'should not save with invalid ref' do
    tag = @customer.tags.build(ref: 'test/test')
    assert_not tag.save, 'Saved with bad ref fields'
  end

  test 'should not save color' do
    tag = @customer.tags.build(label: 'plop', color: 'red')
    assert_not tag.save, 'Saved with invalid color'
  end

  test 'should save' do
    tag = @customer.tags.build(label: 'plop', color: '#ff0000', icon: 'fa-diamond')
    assert tag.save
  end

  test 'two tags from same customer couldnt have same label' do
    @customer.tags.build(label: 'foo').save!
    tag2 = @customer.tags.build(label: 'foo')

    refute tag2.valid?
  end

  test 'default_icon_size uses customer destination icon size' do
    @customer.update!(destination_icon_size: 'large')
    tag = @customer.tags.build(label: 'size-default', color: '#ff0000')

    assert_equal 'large', tag.default_icon_size
  end

  test 'default_icon_size prefers tag value over customer default' do
    @customer.update!(destination_icon_size: 'large')
    tag = @customer.tags.build(label: 'size-override', color: '#ff0000', icon_size: 'small')

    assert_equal 'small', tag.default_icon_size
  end
end
