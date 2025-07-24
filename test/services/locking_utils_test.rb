require 'test_helper'
require 'locking_utils'

class LockingUtilsTest < ActiveSupport::TestCase
  include LockingUtils

  setup do
    @planning = plannings(:planning_one)
  end

  test 'with_locks_on executes the block if the lock is available' do
    executed = false
    with_locks_on(@planning) do
      executed = true
    end
    assert executed, 'The block should be executed when the lock is available'
  end

  test 'with_locks_on raises an error with klass and id if another thread holds the lock' do
    error = nil
    t1_ready = Queue.new
    t1 = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        with_locks_on(@planning) do
          t1_ready.push(true)
          sleep 1
        end
      end
    end

    t2 = Thread.new do
      t1_ready.pop
      begin
        ActiveRecord::Base.connection_pool.with_connection do
          with_locks_on(@planning) do
            # should never be executed
          end
        end
      rescue StandardError => e
        error = e
      end
    end

    t1.join
    t2.join

    assert error, 'An error should be raised if the lock is already held'
    assert error.is_a?(LockingUtils::ResourceLockedError), "Expected ResourceLockedError, got: #{error.class}"
    expected_message = I18n.t('errors.database.locked.resource_locked_with_id', klass: @planning.class.name, id: @planning.id)
    assert_equal expected_message, error.message, "Expected error message to be '#{expected_message}', got: '#{error.message}'"
  end
end
