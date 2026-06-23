# frozen_string_literal: true

require 'test_helper'

class V01::PlanningsPlanningStateTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @planning = plannings(:planning_one)
    @planning.planning_states.delete_all
    customers(:customer_one).update(job_optimizer_id: nil)
  end

  def api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/plannings#{part}.json?api_key=testkey1&" + param.collect { |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
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
            }
          ).to_h
        }) do
          yield
        end
      end
    end
  end

  test 'update_routes active captures planning state as mass action' do
    route = routes(:route_one_one)

    assert_difference -> { PlanningState.unscoped.where(planning_id: @planning.id).count }, 1 do
      patch api("#{@planning.id}/update_routes"), { route_ids: [route.id], selection: 'all', action: 'active' }
    end
    assert last_response.ok?, last_response.body

    state = PlanningState.unscoped.where(planning_id: @planning.id).order(:id).last
    assert_equal 'activate_stops', state.trigger
    assert_equal 'mass', state.category
  end
end
