# frozen_string_literal: true

require 'test_helper'

class PlanningsSelectorPartialTest < ActionView::TestCase
  include PlanningsHelper

  setup do
    @planning = plannings(:planning_one)
    @manage_planning = {
      manage_toggle_routes: true,
      manage_lock_routes: true,
      disable_toggle_routes: false,
      disable_lock_routes: false
    }
  end

  test 'renders searchable checklist instead of select2 route selector' do
    render partial: 'plannings/selector', locals: { summary: planning_summary(@planning) }

    assert_select '#planning-route-selector[data-searchable-checklist-dropdown]'
    assert_select '#planning-route-selector [data-searchable-checklist-filter]'
    assert_select '#planning-route-selector [data-searchable-checklist-action=all]'
    assert_select '#planning-route-selector [data-searchable-checklist-action=clear]'
    assert_select '#planning-route-selector [data-searchable-checklist-action=reverse]'
    assert_select '#planning_route_ids', count: 0
    assert_select '.searchable-checklist-dropdown-option', minimum: 1
  end
end
