# frozen_string_literal: true

require 'test_helper'

class OperationsHelperTest < ActionView::TestCase
  test 'contact_rows_filled_count uses email or phone depending on channel' do
    rows = [
      { email: 'a@example.com', phone: '' },
      { email: '', phone: '0600000000' },
      { email: 'b@example.com', phone: '0611111111' }
    ]

    assert_equal 2, contact_rows_filled_count(rows, :email)
    assert_equal 2, contact_rows_filled_count(rows, :sms)
    assert_equal 0, contact_rows_filled_count(rows, :none)
  end

  test 'contact_rows_count_badge_class is green yellow or red by fill ratio' do
    assert_equal 'text-bg-success', contact_rows_count_badge_class(4, 4)
    assert_equal 'text-bg-warning', contact_rows_count_badge_class(4, 5)
    assert_equal 'text-bg-danger', contact_rows_count_badge_class(3, 4)
    assert_equal 'text-bg-danger', contact_rows_count_badge_class(0, 5)
  end
end
