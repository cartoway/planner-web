# frozen_string_literal: true

require 'test_helper'

# Happy path: rake test:frontend sets FRONTEND_TEST_SUITE=1 → transactional fixtures.
class TransactionalFrontendSuiteTest < ActiveSupport::TestCase
  test 'frontend suite enables use_transactional_tests' do
    skip 'run via rake test:frontend (FRONTEND_TEST_SUITE=1)' unless ENV['FRONTEND_TEST_SUITE'] == '1'

    assert ActiveSupport::TestCase.use_transactional_tests
  end

  # Intentional pair: A dirties a fixture row; B must still see the YAML name after rollback.
  test 'transactional rollback A dirties customer name' do
    skip 'run via rake test:frontend (FRONTEND_TEST_SUITE=1)' unless ENV['FRONTEND_TEST_SUITE'] == '1'

    customers(:customer_one).update!(name: 'SHOULD_ROLLBACK')
    assert_equal 'SHOULD_ROLLBACK', customers(:customer_one).reload.name
  end

  test 'transactional rollback B still sees fixture customer name' do
    skip 'run via rake test:frontend (FRONTEND_TEST_SUITE=1)' unless ENV['FRONTEND_TEST_SUITE'] == '1'

    assert_equal 'MyString', customers(:customer_one).reload.name
  end
end
