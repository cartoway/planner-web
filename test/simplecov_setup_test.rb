# frozen_string_literal: true

require 'test_helper'

# Happy path: partition suite names map to distinct coverage dirs.
class SimplecovSetupTest < ActiveSupport::TestCase
  test 'suite env selects frontend or backend' do
    ENV['TEST_SUITE'] = 'frontend'
    assert_equal 'frontend', SimplecovSetup.suite

    ENV['TEST_SUITE'] = 'backend'
    assert_equal 'backend', SimplecovSetup.suite

    ENV['TEST_SUITE'] = 'other'
    assert_nil SimplecovSetup.suite
  ensure
    ENV.delete('TEST_SUITE')
  end
end
