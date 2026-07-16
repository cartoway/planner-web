# frozen_string_literal: true

require 'test_helper'

class PlanningsControllerPlanningStateTest < ActionController::TestCase
  tests PlanningsController

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @planning = Planning.where(id: plannings(:planning_one).id).preload_route_details.first!
    @planning.planning_states.delete_all
    sign_in users(:user_one)
    customers(:customer_one).update(job_optimizer_id: nil, job_destination_geocoding_id: nil)
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |_url, _mode, _dimension, segments, _options|
      segments.collect { |_i| [1000, 60, '_ibE_seK_seK_seK'] }
    }) do
      Routers::RouterWrapper.stub_any_instance(:matrix, lambda { |_url, _mode, _dimensions, row, column, _options|
        [Array.new(row.size) { Array.new(column.size, 0) }]
      }) do
        OptimizerWrapper.stub_any_instance(:optimize, lambda { |planning, routes, _options|
          returned_stops = routes.flat_map { |r| r.stops.select { |stop| stop.is_a?(StopVisit) } }
          first_route = routes.find { |r| r.vehicle_usage? }
          first_route_rests = first_route.stops.select { |stop| stop.is_a?(StopRest) }.compact
          (
            routes.select { |r| !r.vehicle_usage? }.map { |r| [r.id, []] } +
            routes.select { |r| r.vehicle_usage? }.map.with_index { |r, i|
              [r.id, ((i.zero? ? returned_stops.reverse : []) + first_route_rests).map { |s| { id: s.id, type: s.optim_type } }]
            }.uniq
          ).to_h
        }) do
          yield
        end
      end
    end
  end

  test 'active captures planning state after mutation' do
    assert_difference -> { @planning.planning_states.count }, 1 do
      patch :active, params: { planning_id: @planning, format: :js, route_id: routes(:route_one_one).id, active: :none }, xhr: true
    end
    assert_response :success
    state = @planning.planning_states.order(:id).last
    assert_equal 'active', state.trigger
    assert_equal 'group', state.category
  end

  test 'update_stop captures planning state after mutation' do
    assert_difference -> { @planning.planning_states.count }, 1 do
      patch :update_stop, params: { planning_id: @planning, format: :json, route_id: routes(:route_one_one).id, stop_id: stops(:stop_one_one).id, stop: { active: false } }
    end
    assert_response :success
    state = @planning.planning_states.order(:id).last
    assert_equal 'update_stop', state.trigger
    assert_equal 'individual', state.category
    captured_route = state.payload['routes'].find { |route| route['route_id'] == routes(:route_one_one).id }
    captured_stop = captured_route['stops'].find { |stop| stop['visit_id'] == stops(:stop_one_one).visit_id }
    assert_equal false, captured_stop['active']
    assert_equal false, stops(:stop_one_one).reload.active
  end

  test 'apply_zonings captures planning state after mutation' do
    @planning.zoning_outdated = true
    @planning.save!

    assert_difference -> { @planning.planning_states.count }, 1 do
      patch :apply_zonings, params: { id: @planning, format: :json, planning: { zoning_ids: [zonings(:zoning_one).id] } }
    end
    assert_response :success
    state = @planning.planning_states.order(:id).last
    assert_equal 'apply_zonings', state.trigger
    assert_equal 'mass', state.category
  end

  test 'duplicate captures planning state after mutation' do
    source_planning_id = @planning.id

    assert_difference('Planning.count', 1) do
      assert_difference -> { PlanningState.unscoped.where(trigger: 'duplicate').count }, 1 do
        patch :duplicate, params: { planning_id: @planning }
      end
    end

    assert_redirected_to edit_planning_path(assigns(:planning))
    duplicated = assigns(:planning)
    assert_not_equal source_planning_id, duplicated.id

    state = PlanningState.unscoped.find_by!(planning_id: duplicated.id, trigger: 'duplicate')
    assert_equal 'duplicate', state.trigger
    assert_equal 'mass', state.category
  end
end
