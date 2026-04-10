# frozen_string_literal: true

require 'test_helper'

class PreloadersRouteBatchPreloadTest < ActiveSupport::TestCase
  test 'association trees are frozen' do
    assert Preloaders::RouteBatchPreload::SUMMARY_ASSOCIATIONS.frozen?
    assert Preloaders::RouteBatchPreload::DETAIL_ASSOCIATIONS.frozen?
  end

  test 'associations_for picks summary vs detail' do
    assert_equal Preloaders::RouteBatchPreload::SUMMARY_ASSOCIATIONS,
                 Preloaders::RouteBatchPreload.associations_for(summary: true)
    assert_equal Preloaders::RouteBatchPreload::DETAIL_ASSOCIATIONS,
                 Preloaders::RouteBatchPreload.associations_for(summary: false)
  end
end
