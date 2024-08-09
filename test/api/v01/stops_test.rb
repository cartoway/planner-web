require 'test_helper'

class V01::StopsTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @stop = stops(:stop_one_one)
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1000, 60, '_ibE_seK_seK_seK'] } } ) do
      yield
    end
  end

  def api(planning_id, route_id, part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/plannings/#{planning_id}/routes/#{route_id}/stops#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  test 'should fetch stop' do
    get api(@stop.route.planning.id, @stop.route.id, @stop.id)
    assert last_response.ok?, last_response.body
    assert_equal @stop.id, JSON.parse(last_response.body)['id']
  end

  test 'should update stop' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      put api(@stop.route.planning.id, @stop.route.id, @stop.id, active: false)
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 204, last_response.status, last_response.body
        assert_equal false, @stop.reload.active
      end
    end
  end

  test 'should move stop position in routes' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      patch api(@stop.route.planning.id, @stop.route.id, "#{@stop.route.planning.routes[0].stops[0].id}/move/1")
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 204, last_response.status, last_response.body
        assert_equal 2, @stop.reload.index
        @stop.route.planning.routes.select(&:vehicle_usage).each{ |vu|
          assert_not vu.outdated
        }
      end
    end
  end

  test 'should not move stop position in routes' do
    customers(:customer_one).update(job_optimizer_id: nil)

    # Index is smaller minimum index
    patch api(@stop.route.planning.id, @stop.route.id, "#{@stop.route.planning.routes[0].stops[0].id}/move/0")
    assert_equal 400, last_response.status, last_response.body

    # Index is greater than route size
    patch api(@stop.route.planning.id, @stop.route.id, "#{@stop.route.planning.routes[0].stops[0].id}/move/#{@stop.route.stops.size + 2}")
    assert_equal 400, last_response.status, last_response.body

    # Route doesn't exit
    patch api(@stop.route.planning.id, -1, "#{@stop.route.planning.routes[0].stops[0].id}/move/1")
    assert_equal 404, last_response.status, last_response.body

    # Stop doesn't exist
    patch api(@stop.route.planning.id, @stop.route.id, "-1/move/1")
    assert_equal 404, last_response.status, last_response.body
  end
end
