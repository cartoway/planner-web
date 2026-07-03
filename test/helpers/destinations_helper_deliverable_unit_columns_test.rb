# frozen_string_literal: true

require 'test_helper'

class DestinationsHelperDeliverableUnitColumnsTest < ActionView::TestCase
  include DestinationsHelper

  setup do
    @customer = customers(:customer_one)
    @unit = deliverable_units(:deliverable_unit_one_one)
    @destination = destinations(:destination_two)
  end

  test 'destinations_list_column_label uses deliverable unit label' do
    col_id = Preferences::Catalog::DestinationsList.deliverable_unit_column_id(@unit)
    assert_equal @unit.label, destinations_list_column_label(col_id, @customer)
  end

  test 'destinations_list_deliverable_unit_totals sums visits' do
    totals = destinations_list_deliverable_unit_totals(@destination, @unit)
    assert_in_delta 3.0, totals[:delivery], 1e-6
    assert_in_delta 0.0, totals[:pickup], 1e-6
  end

  test 'destinations_list_deliverable_unit_totals uses unit defaults when visit quantities empty' do
    destination = destinations(:destination_one)
    visit = visits(:visit_one)
    assert_empty visit.deliveries

    totals = destinations_list_deliverable_unit_totals(destination, @unit)
    assert_in_delta @unit.default_delivery.to_f, totals[:delivery], 1e-6
  end

  test 'destinations_list_deliverable_unit_for_visit returns per-visit quantities' do
    visit = visits(:visit_two)
    col_id = Preferences::Catalog::DestinationsList.deliverable_unit_column_id(@unit)
    data = destinations_list_deliverable_unit_for_visit(visit, col_id, @customer)
    assert_equal @unit, data[:unit]
    assert_in_delta 0.0, data[:pickup], 1e-6
    assert_in_delta 3.0, data[:delivery], 1e-6
  end

  test 'destinations_list_column_class maps column ids to css modifiers' do
    assert_equal 'destinations-list-col destinations-list-col--name', destinations_list_column_class('name')
    col_id = Preferences::Catalog::DestinationsList.deliverable_unit_column_id(@unit)
    assert_equal 'destinations-list-col destinations-list-col--deliverable-unit', destinations_list_column_class(col_id)
  end

  test 'destinations_list_tags_tooltip joins tag labels' do
    assert_equal 'tag1', destinations_list_tags_tooltip(destinations(:destination_two).tags.to_a)
  end

  test 'destinations_list_visit_ref returns visit ref or dash' do
    visit = visits(:visit_one)
    assert_equal 'b', destinations_list_visit_ref(visit)
    assert_equal '–', destinations_list_visit_ref(nil)
  end

  test 'destinations_list_visit_subrows_enabled? is true when a visit column is active' do
    col_id = Preferences::Catalog::DestinationsList.deliverable_unit_column_id(@unit)
    assert destinations_list_visit_subrows_enabled?(%w[name visit_ref])
    assert destinations_list_visit_subrows_enabled?(%w[name] + [col_id])
    assert_not destinations_list_visit_subrows_enabled?(%w[name address ref])
  end
end
