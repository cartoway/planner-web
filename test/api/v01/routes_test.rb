require 'test_helper'

class V01::RoutesBaseTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @route = routes(:route_one_one)
  end

  def api(planning_id, part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/plannings/#{planning_id}/routes#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end
end

class V01::RoutesTest < V01::RoutesBaseTest
  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1000, 60, '_ibE_seK_seK_seK'] } } ) do
      Routers::RouterWrapper.stub_any_instance(:matrix, lambda{ |url, mode, dimensions, row, column, options| [Array.new(row.size) { Array.new(column.size, 0) }] }) do
        # return all services in reverse order in first route, rests at the end
        OptimizerWrapper.stub_any_instance(:optimize, lambda { |planning, routes, options|
          (
            [[routes.first.id, routes.flat_map{ |r| r.stops.sort_by(&:index) }.reverse.map(&:id)]]
          ).to_h
        }) do
          yield
        end
      end
    end
  end

  test 'should return 404 with invalid ids' do
    customers(:customer_one).update(job_optimizer_id: nil)
    put api(plannings(:planning_two).id), @route.attributes.except('planning_id')
    assert_equal 404, last_response.status
  end

  test 'should return customer\'s routes' do
    get api(@route.planning.id)
    assert last_response.ok?, last_response.body
    assert_equal @route.planning.routes.size, JSON.parse(last_response.body).size
  end

  test 'should return customer\'s routes by ids' do
    get api(@route.planning.id, nil, 'ids' => @route.id)
    assert last_response.ok?, last_response.body
    assert_equal 1, JSON.parse(last_response.body).size
    assert_equal @route.id, JSON.parse(last_response.body)[0]['id']
  end

  test 'should return a route' do
    get api(@route.planning.id, @route.id)
    assert last_response.ok?, last_response.body
    route = JSON.parse(last_response.body)
    assert_equal @route.stops.size, route['stops'].size
    assert_equal Time.parse('2015-10-11T08:00:00 -1000'), Time.parse(route['start'])
    assert_equal Time.parse('2015-10-10T00:00:30 -1000'), Time.parse(route['stops'][0]['time'])
  end

  test 'should return a route with time exceeding one day' do
    route_multi_days = routes(:route_one_one)

    get api(route_multi_days.planning.id, route_multi_days.id)
    assert last_response.ok?, last_response.body
    route = JSON.parse(last_response.body)
    assert_equal route_multi_days.stops.size, route['stops'].size
    assert_equal Time.parse('2015-10-11T08:00:00 -1000'), Time.parse(route['start'])
    assert_equal Time.parse('2015-10-10T00:00:30 -1000'), Time.parse(route['stops'][0]['time'])
  end

  test 'should update a route' do
    clear_jobs
    @route.locked = true
    put api(@route.planning.id, @route.id), @route.attributes
    assert last_response.ok?, last_response.body

    get api(@route.planning.id, @route.id)
    assert last_response.ok?, last_response.body
    assert_equal @route.locked, JSON.parse(last_response.body)['locked']
  end

  test 'should move stop position in same route' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      patch api(@route.planning.id, "#{@route.id}/stops/#{@route.stops[0].id}/move/3")
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 204, last_response.status, last_response.body
        assert_equal 3, @route.reload.stops.find{ |s| s.visit && s.visit.ref == 'b' }.index
      end
    end
  end

  test 'should move stop position from a route in another' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      patch api(@route.planning.id, "#{@route.id}/stops/#{@route.planning.routes[0].stops[0].id}/move/1")
      assert_equal mode ? 409 : 204, last_response.status, last_response.body
    end
  end

  test 'should not move stop with invalid position' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      patch api(@route.planning.id, "#{@route.id}/stops/#{@route.planning.routes[0].stops[0].id}/move/666")
      assert_equal mode ? 409 : 400, last_response.status, last_response.body
    end
  end

  test 'should change stops activation' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      patch api(@route.planning.id, "#{@route.id}/active/reverse")
      assert_equal mode ? 409 : 200, last_response.status, last_response.body
    end
  end

  test 'should move visits in routes' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      @route.remove_visit(visits(:visit_one)) # routes 1_1 and 3_1 both have a stop belonging to visit_id: 1
      assert_no_difference('Stop.count') do
        r = routes(:route_three_one)
        patch api(@route.planning.id, "#{r.id}/visits/moves").gsub('.json', '.xml'), visit_ids: [visits(:visit_two).id, visits(:visit_one).id]
        if mode
          assert_equal 409, last_response.status, last_response.body
        else
          assert_equal 204, last_response.status, last_response.body
          stops_visit = r.stops.select{ |s| s.is_a? StopVisit }
          # visit_one already belongs to the current route, but is moved at the end of the route
          assert_equal visits(:visit_one).ref, stops_visit[1].visit.ref
          assert_equal visits(:visit_two).ref, stops_visit[0].visit.ref
          @route.planning.routes.select(&:vehicle_usage).each{ |vu|
            assert_not vu.outdated
          }
        end
      end
    end
  end

  test 'should move visits in routes with error' do
    customers(:customer_one).update(job_optimizer_id: nil)
    assert_no_difference('Stop.count') do
      Route.stub_any_instance(:compute, lambda{ |*a| raise }) do
        visit_one = visits(:visit_one)
        visit_two = visits(:visit_two)
        patch api(@route.planning.id, routes(:route_three_one).id.to_s + '/visits/moves'), visit_ids: [visit_two.id, visit_one.id]
        assert_equal 500, last_response.status, last_response.body
        assert visit_two.stop_visits.find{ |s| s.route_id == routes(:route_one_one).id }
        assert visit_one.stop_visits.find{ |s| s.route_id == routes(:route_one_one).id }
      end
    end
  end

  test 'should optimize route with details' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      patch api(@route.planning.id, "#{@route.id}/optimize", details: true, synchronous: true)
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 200, last_response.status, last_response.body
        assert JSON.parse(last_response.body)['id']
      end
    end
  end

  test 'should optimize route with one store rest' do
    customers(:customer_one).update(job_optimizer_id: nil)
    default_order = @route.stops.sort_by(&:index).collect(&:id)

    patch api(@route.planning.id, "#{@route.id}/optimize")
    assert_equal 204, last_response.status, last_response.body

    get api(@route.planning.id, @route.id)
    assert_equal default_order.reverse, JSON.parse(last_response.body)['stops'].collect{ |s| s['id'] }
  end

  test 'should optimize route with one no-geoloc rest' do
    customers(:customer_one).update(job_optimizer_id: nil)
    vehicle_usages(:vehicle_usage_one_one).update! store_rest: nil
    vehicle_usage_sets(:vehicle_usage_set_one).update! store_rest: nil

    default_order = @route.stops.sort_by(&:index).collect(&:id)

    patch api(@route.planning.id, "#{@route.id}/optimize")
    assert_equal 204, last_response.status, last_response.body

    get api(@route.planning.id, @route.id)
    assert_equal default_order.reverse, JSON.parse(last_response.body)['stops'].collect{ |s| s['id'] }
  end

  test 'should optimize all stops in the current route' do
    customers(:customer_one).update(job_optimizer_id: nil)
    [false, true].each do |all|
      patch api(@route.planning.id, "#{@route.id}/optimize", details: true, active_only: all, synchronous: true)
      assert_equal 200, last_response.status, last_response.body
      assert JSON.parse(last_response.body)['id']
    end
  end

  test 'should return a route from vehicle from Ref JSON' do
    get "/api/0.1/plannings/#{@route.planning.id}/routes_by_vehicle/ref:#{vehicles(:vehicle_one).ref}.json?api_key=testkey1"
    assert last_response.ok?, last_response.body
    stops = JSON.parse(last_response.body)['stops']
    assert_equal @route.stops.size, stops.size
    assert_equal Time.parse('2015-10-10T00:00:30 -1000'), Time.parse(stops[0]['time'])
  end

  test 'should return a route from vehicle from ID JSON' do
    get "/api/0.1/plannings/#{@route.planning.id}/routes_by_vehicle/#{vehicles(:vehicle_one).id.to_s}.json?api_key=testkey1"
    assert last_response.ok?, last_response.body
    stops = JSON.parse(last_response.body)['stops']
    assert_equal @route.stops.size, stops.size
    assert_equal Time.parse('2015-10-10T00:00:30 -1000'), Time.parse(stops[0]['time'])
  end

  test 'should return a route from vehicle from Ref XML' do
    get "/api/0.1/plannings/#{@route.planning.id}/routes_by_vehicle/ref:#{vehicles(:vehicle_one).ref}.xml?api_key=testkey1"
    assert last_response.ok?, last_response.body
    stops = Hash.from_xml(last_response.body)['hash']['stops']
    assert_equal @route.stops.size, stops.size
    assert_equal Time.parse('2015-10-10T00:00:30 -1000'), stops[0]['time']
  end

  test 'should return a route from vehicle from ID XML' do
    get "/api/0.1/plannings/#{@route.planning.id}/routes_by_vehicle/#{vehicles(:vehicle_one).id.to_s}.xml?api_key=testkey1"
    assert last_response.ok?, last_response.body
    stops = Hash.from_xml(last_response.body)['hash']['stops']
    assert_equal @route.stops.size, stops.size
    assert_equal Time.parse('2015-10-10T00:00:30 -1000'), stops[0]['time']
  end

  test 'should not return route because not found' do
    ["/api/0.1/plannings/1234/routes_by_vehicle/#{@route.id}.json?api_key=testkey1",
      "/api/0.1/plannings/#{@route.planning.id}/routes_by_vehicle/1234.json?api_key=testkey1"].each do |url|
      get url
      assert_equal(404, last_response.status)
    end
  end

  test 'should update stops order' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      planning = @route.planning
      stops_index = @route.stops.map{ |s| s[:index] + s[:id] }
      patch "/api/0.1/plannings/#{planning[:id]}/routes/#{@route[:id]}/reverse_order?api_key=testkey1"
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert last_response.ok?, last_response.body
        l = planning.routes.find(@route.id).stops.map{ |s| s[:index] + s[:id] }
        assert_not_equal stops_index, l
      end
    end
  end

  test 'should provide the good stops order' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      planning = @route.planning
      stops_hash = @route.stops.each_with_object({}){ |stop, hash| hash[stop[:id]] = stop[:index] }
      patch "/api/0.1/plannings/#{planning[:id]}/routes/#{@route[:id]}/reverse_order?api_key=testkey1"
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert last_response.ok?, last_response.body
        stops_hash_new = planning.routes.find(@route.id).stops.each_with_object({}){ |stop, hash| hash[stop[:id]] = stop[:index] }
        stops_hash.each do |k, v|
          assert_not_equal stops_hash_new[k], v
          assert_equal true, stops_hash_new[k] == (stops_hash.size) - (stops_hash[k] - 1)
        end
      end
    end
  end

  test 'should return a route with deprecated attributs' do
    @route.outdated = true
    @route.save!

    get api(@route.planning_id, @route.id)
    assert last_response.ok?, last_response.body
    json = JSON.parse(last_response.body)
    assert json['outdated']
    assert json['out_of_date']
  end

  test 'should send SMS for each stop visit' do
    @route.planning.customer.reseller.update(messagings: {sms_partner: { enable: true, api_key: :sms_api_key, api_secret: :sms_api_secret }})
    @route.planning.customer.update enable_sms: true

    SmsPartnerService.stub_any_instance(:send_message, true) do
      get api(@route.planning_id, "#{@route.id}/send_sms")
      assert last_response.ok?, 'Bad response: ' + last_response.body
      assert_equal '3', last_response.body
    end
  end

  test 'should find route by ref case insensitive' do
    # Set a specific ref for the route
    @route.update(ref: 'TestRoute')

    # Test different case variations for GET
    ['ref:testroute', 'ref:TestRoute', 'ref:TESTROUTE', 'ref:TeStRoUtE'].each do |ref_variant|
      get api(@route.planning_id, ref_variant)
      assert last_response.ok?, "Failed for ref variant: #{ref_variant}"
      response = JSON.parse(last_response.body)
      assert_equal @route.id, response['id'], "Route not found for ref variant: #{ref_variant}"
      assert_equal 'TestRoute', response['ref'], "Ref not preserved correctly for variant: #{ref_variant}"
    end
  end
end

class V01::RoutesErrorTest < V01::RoutesBaseTest

  test 'should optimize route and return no solution found' do
    customers(:customer_one).update(job_optimizer_id: nil)
    OptimizerWrapper.stub_any_instance(:optimize, lambda{ |*_a| raise VRPNoSolutionError.new }) do
      patch api(@route.planning.id, "#{@route.id}/optimize", details: true)
      assert_equal 304, last_response.status, last_response.body
    end
  end

end
