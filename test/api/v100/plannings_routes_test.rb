require 'test_helper'

class V100::PlanningsRoutesTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @planning = plannings(:planning_one)
    customers(:customer_one).update(enable_store_stops: true)
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1000, 60, '_ibE_seK_seK_seK'] } } ) do
      OptimizerWrapper.stub_any_instance(:optimize, lambda { |planning, routes, options|
          # Put all the stops on the first available route with a vehicle
          returned_stops = routes.flat_map{ |r| r.stops.select{ |stop| stop.is_a?(StopVisit) }}
          first_route = routes.find{ |r| r.vehicle_usage? }
          first_route_rests = first_route.stops.select{ |stop| stop.is_a?(StopRest) }.compact
          (
            routes.select{ |r| !r.vehicle_usage? }.map{ |r| [r.id, []] } +
            routes.select{ |r| r.vehicle_usage? }.map.with_index{ |r, i| [r.id, ((i.zero? ? returned_stops.reverse : []) + first_route_rests).map(&:id) + options[:moving_stop_ids]] }.uniq
          ).to_h
      }) do
        yield
      end
    end
  end

  def api(planning_id, part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/100/plannings/#{planning_id}/routes#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  test 'should move stop to route' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      unassigned_stop = @planning.routes.detect{ |route| !route.vehicle_usage }.stops.select(&:position?).first
      first_route_with_vehicle = @planning.routes.find{ |route| route.vehicle_usage }

      patch api(@planning.id, "/#{first_route_with_vehicle.id}/stops/moves"), nil, input: { stop_ids: [unassigned_stop.id] }.to_json, CONTENT_TYPE: 'application/json'

      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 204, last_response.status, last_response.body
        assert @planning.routes.reload.select(&:vehicle_usage).any?{ |route| route.stops.select(&:active).map(&:id).include?(unassigned_stop.id) }
        @planning.routes.select(&:vehicle_usage).each{ |vu|
          assert_not vu.outdated
        }
      end
    end
  end

  test 'should move visits to route' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      unassigned_stop = @planning.routes.detect{ |route| !route.vehicle_usage }.stops.select(&:position?).first
      first_route_with_vehicle = @planning.routes.find{ |route| route.vehicle_usage }

      patch api(@planning.id, "/#{first_route_with_vehicle.id}/visits/moves"), nil, input: { visit_ids: [unassigned_stop.visit.id] }.to_json, CONTENT_TYPE: 'application/json'

      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 204, last_response.status, last_response.body
        assert @planning.routes.reload.select(&:vehicle_usage).any?{ |route| route.stops.select(&:active).map(&:id).include?(unassigned_stop.id) }
        @planning.routes.select(&:vehicle_usage).each{ |vu|
          assert_not vu.outdated
        }
      end
    end
  end

  test 'should add store to route' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      route = @planning.routes.find{ |r| r.vehicle_usage }
      store = stores(:store_one)
      post api(@planning.id, "/#{route.id}/stores/#{store.id}"), nil, input: { index: 0 }.to_json, CONTENT_TYPE: 'application/json'
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 201, last_response.status, last_response.body
        route.reload
        assert_equal store, route.stops.first.store
      end
    end
  end

  test 'should not add store to out_route' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      route = @planning.routes.find{ |r| !r.vehicle_usage }
      store = stores(:store_one)
      post api(@planning.id, "/#{route.id}/stores/#{store.id}"), nil, input: { index: 0 }.to_json, CONTENT_TYPE: 'application/json'
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 500, last_response.status, last_response.body
        assert_equal(
          I18n.t('activerecord.errors.models.route.attributes.stops.store.must_be_associated_to_vehicle_usage'),
          JSON.parse(last_response.body)['message']
        )
      end
    end
  end

  test 'should not add store to route when enable_store_stops is false' do
    customers(:customer_one).update(enable_store_stops: false)
    route = @planning.routes.find{ |r| !r.vehicle_usage }
    store = stores(:store_one)

    assert_no_difference('StopStore.count') do
      post api(@planning.id, "/#{route.id}/stores/#{store.id}"), nil, input: { index: 0 }.to_json, CONTENT_TYPE: 'application/json'
      assert_equal 401, last_response.status, last_response.body

      content = JSON.parse(last_response.body, symbolize_names: true)
      assert_match I18n.t('errors.routes.enable_store_stops'), content[:message]
    end

    route.reload
    assert route.stops.none?{ |s| s.is_a?(StopStore) && s.store_id == @store.id }
  end
end
