# frozen_string_literal: true

require 'test_helper'

class LookbookVisualRegressionEnabledTest < ActiveSupport::TestCase
  setup do
    @previous = ENV.fetch('LOOKBOOK_VRT', nil)
  end

  teardown do
    ENV['LOOKBOOK_VRT'] = @previous
  end

  test 'enabled? is true only when LOOKBOOK_VRT=1' do
    ENV.delete('LOOKBOOK_VRT')
    assert_not Lookbook::VisualRegression.enabled?

    ENV['LOOKBOOK_VRT'] = '0'
    assert_not Lookbook::VisualRegression.enabled?

    ENV['LOOKBOOK_VRT'] = '1'
    assert Lookbook::VisualRegression.enabled?
  end
end
