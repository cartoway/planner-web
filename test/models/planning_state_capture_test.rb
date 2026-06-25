# frozen_string_literal: true

require 'test_helper'
require 'routers/router_wrapper'

class PlanningStateCaptureTest < ActiveSupport::TestCase
  setup do
    @planning = Planning.where(id: plannings(:planning_one).id).preload_route_details.first!
    @planning.planning_states.delete_all
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |_url, _mode, _dimension, segments, _options|
      segments.collect { |_i| [1, 1, '_ibE_seK_seK_seK'] }
    }) do
      Routers::RouterWrapper.stub_any_instance(:matrix, lambda { |_url, _mode, _dimensions, row, column, _options|
        [Array.new(row.size) { Array.new(column.size, 0) }]
      }) do
        yield
      end
    end
  end

  test 'capture_state stores structure and statistics' do
    assert_difference('PlanningState.count', 1) do
      @planning.capture_state!(trigger: 'move')
    end

    state = @planning.planning_states.first
    assert_equal 'move', state.trigger
    assert_equal 'individual', state.category
    assert state.payload['routes'].present?
    assert state.statistics.key?('distance_total')
    assert state.statistics.key?('duration_total')
    assert state.statistics.key?('stops_size')
    assert state.statistics.key?('routes_visits_duration')
  end

  test 'capture_state does not load stops on planning association' do
    planning = Planning.where(id: plannings(:planning_one).id).preload_routes_without_stops.first!

    planning.capture_state!(trigger: 'move')

    assert planning.association(:routes).loaded?
    assert planning.routes.all? { |route| !route.association(:stops).loaded? }
  end

  test 'capture_state runs compute_saved before persisting' do
    compute_called = false

    @planning.stubs(:compute_saved!).with(bang: false) do
      compute_called = true
      true
    end
    @planning.capture_state!(trigger: 'move')

    assert compute_called
  end

  test 'capture_state skips route compute when all routes are up to date' do
    planning = Planning.where(id: plannings(:planning_one).id).preload_routes_without_stops.first!
    planning.planning_states.delete_all
    planning.routes.update_all(outdated: false)

    Route.any_instance.stubs(:compute!).raises('compute! should not run when routes are up to date')
    Route.any_instance.stubs(:compute).raises('compute should not run when routes are up to date')
    assert_difference('PlanningState.count', 1) do
      planning.capture_state!(trigger: 'update_stop')
    end
  end

  test 'capture_state does not persist when compute_saved fails' do
    @planning.stubs(:compute_saved!).returns(false)
    assert_no_difference('PlanningState.count') do
      @planning.capture_state!(trigger: 'move')
    end
  end

  test 'capture_state stores stop rests in snapshot' do
    route = routes(:route_one_one)
    rest = stops(:stop_one_four)

    @planning.capture_state!(trigger: 'move')
    route_snapshot = @planning.planning_states.last.payload['routes'].find { |snapshot| snapshot['route_id'] == route.id }
    rest_snapshot = route_snapshot['stops'].find { |stop| stop['type'] == 'rest' }

    assert rest_snapshot
    assert_equal rest.active, rest_snapshot['active']
    assert_equal rest.index, rest_snapshot['index']
  end

  test 'reapply_state restores stop rests from snapshot' do
    route = routes(:route_one_one)
    rest = stops(:stop_one_four)
    vehicle_usage_id = route.vehicle_usage_id

    @planning.capture_state!(trigger: 'move')
    state = @planning.planning_states.last

    Stop.where(route_id: route.id, type: StopRest.name).delete_all
    route.reload
    assert_empty route.stops.grep(StopRest)

    assert @planning.reapply_state!(state)
    @planning.reload

    restored_route = @planning.routes.find { |snapshot| snapshot.vehicle_usage_id == vehicle_usage_id }
    restored_rest = restored_route.stops.grep(StopRest).first
    assert restored_rest
    assert_equal rest.index, restored_rest.index
    assert_equal rest.active, restored_rest.active
  end

  test 'reapply_state restores structure from snapshot' do
    @planning.capture_state!(trigger: 'move')
    state = @planning.planning_states.first

    @planning.routes.select(&:vehicle_usage?).each { |route| route.set_visits([], false) }

    assert @planning.reapply_state!(state)
    @planning.reload

    snapshot_visit_ids =
      state.payload['routes'].flat_map { |route| route['stops'] }
        .select { |stop| stop['type'] == 'visit' }
        .map { |stop| stop['visit_id'] }
    current_visit_ids = @planning.routes.flat_map(&:stops).grep(StopVisit).map(&:visit_id)

    assert_equal snapshot_visit_ids.sort, current_visit_ids.sort
  end

  test 'reapply_state restores visits when snapshot includes out of route route' do
    out_of_route = @planning.routes.find { |route| !route.vehicle_usage? }
    visit = visits(:visit_one)
    out_of_route.set_visits([visit], false)

    @planning.capture_state!(trigger: 'move')
    state = @planning.planning_states.first
    assert state.payload['routes'].any? { |route| route['vehicle_usage_id'].nil? }

    @planning.routes.each { |route| route.set_visits([], false) }
    assert_empty @planning.routes.flat_map(&:stops).grep(StopVisit)

    assert @planning.reapply_state!(state)
    @planning.reload

    snapshot_visit_ids =
      state.payload['routes'].flat_map { |route| route['stops'] }
        .select { |stop| stop['type'] == 'visit' }
        .map { |stop| stop['visit_id'] }
    current_visit_ids = @planning.routes.flat_map(&:stops).grep(StopVisit).map(&:visit_id)

    assert_equal snapshot_visit_ids.sort, current_visit_ids.sort
  end

  test 'reapply_state does not capture a new state' do
    @planning.capture_state!(trigger: 'move')
    state = @planning.planning_states.first

    assert_no_difference('PlanningState.count') do
      @planning.reapply_state!(state)
    end
  end

  test 'optimizer job captures planning state after optimization' do
    route = routes(:route_one_one)

    OptimizerWrapper.stub_any_instance(:optimize, lambda { |*_args|
      routes = _args[1]
      returned_stops = routes.flat_map { |r| r.stops.select { |stop| stop.is_a?(StopVisit) } }
      first_route = routes.find { |r| r.vehicle_usage? }
      first_route_rests = first_route.stops.select { |stop| stop.is_a?(StopRest) }.compact
      (
        routes.select { |r| !r.vehicle_usage? }.map { |r| [r.id, []] } +
        routes.select { |r| r.vehicle_usage? }.map.with_index { |r, i|
          [r.id, ((i.zero? ? returned_stops.reverse : []) + first_route_rests).map { |s| { id: s.id, type: s.optim_type } }]
        }
      ).to_h
    }) do
      assert_difference -> { @planning.planning_states.where(trigger: 'optimize_route').count }, 1 do
        OptimizerJob.new(@planning.customer_id, @planning.id, route.id, **{ global: false }).perform
      end
    end

    state = @planning.planning_states.where(trigger: 'optimize_route').order(:id).last
    assert_equal 'optimize_route', state.trigger
    assert_equal 'group', state.category
  end

  test 'optimizer job captures planning state when executed as delayed job' do
    route = routes(:route_one_one)
    optimizer_job = OptimizerJob.new(@planning.customer_id, @planning.id, route.id, **{ global: false })
    delayed_job = delayed_jobs(:job_optimizer)

    OptimizerWrapper.stub_any_instance(:optimize, lambda { |*_args|
      routes = _args[1]
      returned_stops = routes.flat_map { |r| r.stops.select { |stop| stop.is_a?(StopVisit) } }
      first_route = routes.find { |r| r.vehicle_usage? }
      first_route_rests = first_route.stops.select { |stop| stop.is_a?(StopRest) }.compact
      (
        routes.select { |r| !r.vehicle_usage? }.map { |r| [r.id, []] } +
        routes.select { |r| r.vehicle_usage? }.map.with_index { |r, i|
          [r.id, ((i.zero? ? returned_stops.reverse : []) + first_route_rests).map { |s| { id: s.id, type: s.optim_type } }]
        }
      ).to_h
    }) do
      optimizer_job.before(delayed_job)
      assert_difference -> { @planning.planning_states.where(trigger: 'optimize_route').count }, 1 do
        optimizer_job.perform
      end
    end

    state = @planning.planning_states.where(trigger: 'optimize_route').order(:id).last
    assert_equal 'optimize_route', state.trigger
  end
end
