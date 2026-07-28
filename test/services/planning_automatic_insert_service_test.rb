require 'test_helper'
require 'routers/router_wrapper'

class PlanningAutomaticInsertServiceTest < ActiveSupport::TestCase
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

  test 'call resets traces on impacted route' do
    planning = plannings(:planning_one)
    planning.zonings = []
    stop = planning.routes.find { |r| !r.vehicle_usage? }.stops.first

    planning.routes.select(&:vehicle_usage?).each do |route|
      route.outdated = true
      route.compute
      assert route.instance_variable_get(:@traces).present?
    end

    impacted_routes = PlanningAutomaticInsertService.new(planning, [stop]).call

    assert_equal 1, impacted_routes.size
    assert_nil impacted_routes.first.instance_variable_get(:@traces)
  end
end
