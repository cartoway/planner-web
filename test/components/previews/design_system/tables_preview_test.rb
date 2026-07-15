# frozen_string_literal: true

require 'test_helper'

class DesignSystem::TablesPreviewTest < ActiveSupport::TestCase
  test 'destinations_list render_args expose static sample data to the template' do
    args = DesignSystem::TablesPreview.render_args(:destinations_list)

    assert args[:assigns].present?
    assert_equal Lookbook::DestinationsListSample.customer, args[:assigns][:customer]
    assert_equal 3, args[:assigns][:destinations].size
    assert_equal 'Boulangerie Dupont', args[:assigns][:destinations].first.name
    assert args[:assigns][:destinations_list_columns].present?
    assert args[:assigns][:pagination].present?
    assert_includes args[:assigns][:destinations_list_columns], 'ref'
  end
end
