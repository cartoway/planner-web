# frozen_string_literal: true

# Grape API wraps each request in begin_transaction (see V01::Api / V100::Api).
# Under use_transactional_tests that nests as a joinable savepoint on top of the
# non-joinable test transaction — only roll back / commit the joinable one.
module ApiRequestTransaction
  module_function

  def rollback!
    conn = ActiveRecord::Base.connection
    return unless conn.transaction_open?
    return unless conn.current_transaction.joinable?

    conn.rollback_transaction
  end

  def commit!
    conn = ActiveRecord::Base.connection
    return unless conn.transaction_open?
    return unless conn.current_transaction.joinable?

    conn.commit_transaction
  end
end
