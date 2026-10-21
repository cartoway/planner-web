# frozen_string_literal: true

require 'test_helper'

# Happy path: suite uses transactional fixtures (rollback between tests).
class TransactionalFrontendSuiteTest < ActiveSupport::TestCase
  test 'use_transactional_tests is enabled by default' do
    assert ActiveSupport::TestCase.use_transactional_tests
  end

  # Intentional pair: A dirties a fixture row; B must still see the YAML name after rollback.
  test 'transactional rollback A dirties customer name' do
    customers(:customer_one).update!(name: 'SHOULD_ROLLBACK')
    assert_equal 'SHOULD_ROLLBACK', customers(:customer_one).reload.name
  end

  test 'transactional rollback B still sees fixture customer name' do
    assert_equal 'MyString', customers(:customer_one).reload.name
  end
end
