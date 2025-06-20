require 'test_helper'

class QuantityAttrTest < ActiveSupport::TestCase
  test "should create independent copy with dup" do
    original = QuantityAttr::QuantityHash.new(0)
    original[1] = 10
    original[2] = 20

    copy = original.dup

    # Verify they have the same content initially
    assert_equal original, copy

    # Verify they are different objects
    assert_not_equal original.object_id, copy.object_id

    # Modify the copy
    copy[1] = 30

    # Verify the original is not affected
    assert_equal 10, original[1]
    assert_equal 30, copy[1]

    # Verify they are no longer equal
    assert_not_equal original, copy
  end

  test "should create QuantityHash with correct type" do
    original = QuantityAttr::QuantityHash.new(0)
    copy = original.dup

    assert_instance_of QuantityAttr::QuantityHash, copy
  end
end
