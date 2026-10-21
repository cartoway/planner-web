# frozen_string_literal: true

require 'test_helper'

class ApiRequestTransactionTest < ActiveSupport::TestCase
  test 'rollback and commit only touch joinable request savepoints' do
    conn = ActiveRecord::Base.connection
    # use_transactional_tests already opened a non-joinable wrapper.
    refute conn.current_transaction.joinable?

    before_zones = Zone.count
    conn.begin_transaction # joinable savepoint (like Grape before)
    Zone.delete_all
    assert_equal 0, Zone.count

    ApiRequestTransaction.rollback!
    assert_equal before_zones, Zone.count
    refute conn.current_transaction.joinable?

    # Second rollback must not unwind the test wrapper.
    ApiRequestTransaction.rollback!
    assert conn.transaction_open?
    assert_equal before_zones, Zone.count
  end
end
