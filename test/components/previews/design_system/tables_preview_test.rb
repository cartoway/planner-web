# frozen_string_literal: true

require 'test_helper'

class DesignSystem::TablesPreviewTest < ActiveSupport::TestCase
  remove_method(:test_destinations_list_preview_exposes_pagination_sample_with_first_and_last_controls_context) if
    method_defined?(:test_destinations_list_preview_exposes_pagination_sample_with_first_and_last_controls_context)

  def test_destinations_list_preview_exposes_pagination_sample_with_first_and_last_controls_context
    args = DesignSystem::TablesPreview.render_args(:destinations_list)

    assert args[:assigns].present?
    assert_equal Lookbook::DestinationsListSample.customer, args[:assigns][:customer]
    assert_equal 4, args[:assigns][:destinations].size
    assert_equal 'Boulangerie Dupont', args[:assigns][:destinations].first.name
    assert args[:assigns][:destinations_list_columns].present?
    assert args[:assigns][:pagination].present?
    assert_equal 5, args[:assigns][:pagination][:page]

    customer = Lookbook::DestinationsListSample.customer
    expected_columns = (
      Preferences::Catalog::DestinationsList.default_active_for(customer) + %w[tags visit_tags]
    ).uniq & Preferences::Catalog.destinations_list_allowed_column_ids(customer)
    assert_equal expected_columns, args[:assigns][:destinations_list_columns]
    assert_not_includes args[:assigns][:destinations_list_columns], 'ref'
  end
end
