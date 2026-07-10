# frozen_string_literal: true

require 'test_helper'

class LookbookVisualRegressionSnapshotBasenameTest < ActiveSupport::TestCase
  test 'normalize replaces underscores with dashes for Playwright snapshot files' do
    assert_equal 'buttons-button-groups', Lookbook::VisualRegression::SnapshotBasename.normalize('buttons-button_groups')
    assert_equal 'grid-layout-breakpoints-and-offset',
                 Lookbook::VisualRegression::SnapshotBasename.normalize('grid_layout-breakpoints_and_offset')
  end
end
