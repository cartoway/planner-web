require 'test_helper'

class V100::StopsTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @planning = plannings(:planning_one)
    @route = @planning.routes.find{ |route| route.vehicle_usage }
    @store = stores(:store_one)
    @stop_store = @route.add_store(@store, 1)
    @stop_store.save!
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

  def api(planning_id, route_id, stop_id, param = {})
    "/api/100/plannings/#{planning_id}/routes/#{route_id}/stops/#{stop_id}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  test 'should delete stop store' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      delete api(@planning.id, @route.id, @stop_store.id)
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 204, last_response.status, last_response.body
        @route.reload
        assert @route.stops.none?{ |s| s.is_a?(StopStore) }
      end
    end
  end

  test 'should not delete stop visit' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      stop_visit = stops(:stop_one_one)
      assert_no_difference('StopVisit.count') do
        delete api(@planning.id, @route.id, stop_visit.id)
        if mode
          assert_equal 409, last_response.status, last_response.body
        else
          assert_equal 404, last_response.status, last_response.body
        end
      end
    end
  end

  test 'should not delete stop rest' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      stop_rest = stops(:stop_one_four)
      assert_no_difference('StopRest.count') do
        delete api(@planning.id, @route.id, stop_rest.id)
        if mode
          assert_equal 409, last_response.status, last_response.body
        else
          assert_equal 404, last_response.status, last_response.body
        end
      end
    end
  end

  test 'should return 404 for non-existent planning' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      delete api(99999, @route.id, @stop_store.id)
      assert_equal 404, last_response.status, last_response.body
    end
  end

  test 'should return 404 for non-existent route' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      delete api(@planning.id, 99999, @stop_store.id)
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 404, last_response.status, last_response.body
      end
    end
  end

  test 'should return 404 for non-existent stop' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      delete api(@planning.id, @route.id, 99999)
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 404, last_response.status, last_response.body
      end
    end
  end

  test 'should compute route after deleting stop' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      delete api(@planning.id, @route.id, @stop_store.id)
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 204, last_response.status, last_response.body
        @route.reload
        assert_not @route.outdated
      end
    end
  end
end
