require 'test_helper'

class V01::PlanningsBaseTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @planning = plannings(:planning_one)
  end

  def api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/plannings#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end
end

class V01::PlanningsTest < V01::PlanningsBaseTest
  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1000, 60, '_ibE_seK_seK_seK'] } } ) do
      Routers::RouterWrapper.stub_any_instance(:matrix, lambda{ |url, mode, dimensions, row, column, options| [Array.new(row.size) { Array.new(column.size, 0) }] }) do
        # return all services in reverse order in first route, rests at the end
        OptimizerWrapper.stub_any_instance(:optimize, lambda { |planning, routes, options|
          # Put all the stops on the first available route with a vehicle
          returned_stops = routes.flat_map{ |r| r.stops.select{ |stop| stop.is_a?(StopVisit) }}
          first_route = routes.find{ |r| r.vehicle_usage? }
          first_route_rests = first_route.stops.select{ |stop| stop.is_a?(StopRest) }.compact
          (
            routes.select{ |r| !r.vehicle_usage? }.map{ |r| [r.id, []] } +
            routes.select{ |r| r.vehicle_usage? }.map.with_index{ |r, i| [r.id, ((i.zero? ? returned_stops.reverse : []) + first_route_rests).map{ |s| { id: s.id, type: s.optim_type }}] }
          ).to_h
        }) do
         yield
        end
      end
    end
  end

  test "should return customer's plannings" do
    get api()
    assert last_response.ok?, last_response.body
    assert_equal @planning.customer.plannings.size, JSON.parse(last_response.body).size
  end

  test "should return customer's plannings by ids" do
    get api(nil, ids: "#{@planning.id},ref:#{plannings(:planning_two).ref}")
    assert last_response.ok?, last_response.body
    body = JSON.parse(last_response.body)
    assert_equal 2, body.size
    assert_includes(body.map { |p| p['id'] }, @planning.id)
    assert_includes(body.map { |p| p['ref'] }, plannings(:planning_two).ref)
  end

  test 'should return a planning' do
    get api(@planning.id)
    assert last_response.ok?, last_response.body
    assert_equal @planning.name, JSON.parse(last_response.body)['name']
  end

  test 'should return a planning by ref' do
    get api("ref:#{@planning.ref}")
    assert last_response.ok?, last_response.body
    assert_equal @planning.ref, JSON.parse(last_response.body)['ref']
  end

  test 'should find planning by ref case insensitive' do
    @planning.update(ref: 'TestRef')

    ['testref', 'TestRef', 'TESTREF', 'TeStReF'].each do |ref_variant|
      get api("ref:#{ref_variant}")
      assert last_response.ok?, "Failed for ref variant: #{ref_variant}"
      response = JSON.parse(last_response.body)
      assert_equal @planning.id, response['id'], "Planning not found for ref variant: #{ref_variant}"
      assert_equal 'TestRef', response['ref'], "Ref not preserved correctly for variant: #{ref_variant}"
    end
  end

  test 'should create a planning' do
    assert_difference('Planning.count', 1) do
      @planning.name = 'new name'
      post api(), @planning.attributes.merge({tag_operation: 'and', tag_ids: tags(:tag_one).id, zoning_ids: [zonings(:zoning_one).id]})
      assert last_response.created?, last_response.body
      response = JSON.parse(last_response.body)
      assert_equal true, response['active']
      assert_equal 1, response['tag_ids'].size
      assert_equal 1, response['zoning_ids'].size
    end
  end

  test 'should create a planning with begin and end date' do
    assert_difference('Planning.count', 1) do
      @planning.name = 'new name'
      post api(), @planning.attributes.merge({tag_operation: 'and', begin_date: '20-04-2017', end_date: '25-04-2017'})
      assert last_response.created?, last_response.body
      response = JSON.parse(last_response.body)
      assert_equal '2017-04-20', response['begin_date']
      assert_equal '2017-04-25', response['end_date']
    end
  end

  test 'should create a planning with selected tags and according to tag operation' do
    planning = plannings(:planning_four)

    assert_difference('Planning.count', 1) do
      post '/api/0.1/plannings.json?api_key=testkey3', nil, input: planning.attributes.merge({tag_ids: [tags(:tag_three).id, tags(:tag_four).id], tag_operation: 'and'}).to_json, CONTENT_TYPE: 'application/json'
      assert last_response.created?, last_response.body
      response = JSON.parse(last_response.body)
      assert_equal 2, response['tag_ids'].size
      new_planning = Planning.last
      assert_equal 2, new_planning.tags.size

      # Check number of visits (including both tags) associated to the new planning
      assert_equal 1, new_planning.visits_compatibles.count
      # Check number of stops (including both tags) in the new planning
      assert_equal 1, new_planning.routes[0].stops.size
    end

    assert_difference('Planning.count', 1) do
      post '/api/0.1/plannings.json?api_key=testkey3', nil, input: planning.attributes.merge({tag_ids: [tags(:tag_three).id, tags(:tag_four).id], tag_operation: 'or'}).to_json, CONTENT_TYPE: 'application/json'
      assert last_response.created?, last_response.body
      response = JSON.parse(last_response.body)
      assert_equal 2, response['tag_ids'].size
      new_planning = Planning.last

      # Check number of visits (including at least one tag) associated to the new planning
      assert_equal 2, new_planning.visits_compatibles.count
      # Check number of stops (including at least one tags) in the new planning
      assert_equal 2, new_planning.routes[0].stops.size
    end
  end

  test 'should not create a planning with inconsistent data' do
    {
      vehicle_usage_set_id: 0,
      zoning_ids: [zonings(:zoning_three).id]
    }.each{ |k, v|
      attributes = @planning.attributes.merge(name: 'new name', tag_operation: 'and')
      attributes[k] = v
      post api(), attributes
      assert_equal 400, last_response.status
    }
  end

  test 'should update a planning' do
    @planning.name = 'new name'
    put api(@planning.id), @planning.attributes.merge(tag_operation: 'and')
    assert last_response.ok?, last_response.body

    get api(@planning.id)
    assert last_response.ok?, last_response.body
    assert_equal @planning.name, JSON.parse(last_response.body)['name']
  end

  test 'should destroy a planning' do
    assert_difference('Planning.count', -1) do
      delete api(@planning.id)
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should destroy multiple plannings' do
    assert_difference('Planning.count', -2) do
      delete api + "&ids=#{plannings(:planning_one).id},ref:#{plannings(:planning_two).ref}"
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should force recompute the planning after parameter update' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      patch api("#{@planning.id}/refresh")
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert last_response.ok?, last_response.body
      end
    end
  end

  test 'should switch two vehicles' do
    routes = @planning.routes.load.select{ |route| route.vehicle_usage_id }
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      patch api("#{@planning.id}/switch"), {id: @planning.id, route_id: routes.first.id, vehicle_usage_id: routes.second.vehicle_usage_id}
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 204, last_response.status, last_response.body
        @planning.routes.reload
        assert_equal routes.first.vehicle_usage_id, @planning.routes.find{ |route| route.id == routes.second.id }.vehicle_usage_id
        assert_equal routes.second.vehicle_usage_id, @planning.routes.find{ |route| route.id == routes.first.id }.vehicle_usage_id
        @planning.routes.select(&:vehicle_usage).each{ |vu|
          assert_not vu.outdated
        }
      end
    end
  end

  #  test 'should set stop status' do
  #    patch api("#{@planning.id}/update_stop")
  #    assert last_response.ok?, last_response.body
  #  end

  #  test 'should starts asynchronous route optimization' do
  #    get api("#{@planning.id}/optimize_route")
  #    assert last_response.ok?, last_response.body
  #  end

  test 'should change stops activation' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      patch api("#{@planning.id}/routes/#{@planning.routes[1].id}/active/all")
      assert_equal mode ? 409 : 200, last_response.status, last_response.body
      patch api("#{@planning.id}/routes/#{@planning.routes[1].id}/active/reverse")
      assert_equal mode ? 409 : 200, last_response.status, last_response.body
    end
  end

  test 'should clone planning' do
    assert_difference('Planning.count', 1) do
      patch api("#{@planning.id}/duplicate")
      assert last_response.ok?, last_response.body
    end
  end

  test 'should automatic insert stop with ID from unassigned' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      unassigned_stop = @planning.routes.detect{ |route| !route.vehicle_usage }.stops.select(&:position?).first
      patch api("#{@planning.id}/automatic_insert"), nil, input: { stop_ids: [unassigned_stop.id], out_of_zone: true }.to_json, CONTENT_TYPE: 'application/json'
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

  test 'should automatic insert stop with Ref from existing route with vehicle' do
    @planning.compute_saved!
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      last_stop = routes(:route_one_one).stops.select(&:position?).last
      last_stop.update! active: false

      patch api("ref:#{@planning.ref}/automatic_insert"), nil, input: { stop_ids: [last_stop.id], out_of_zone: true }.to_json, CONTENT_TYPE: 'application/json'
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 204, last_response.status, last_response.body
        routes = @planning.routes.reload.select(&:vehicle_usage)
        assert routes.any?{ |route| route.stops.select(&:active).map(&:id).include?(last_stop.id) }
        assert routes.all?{ |r| r.stops.collect(&:index).sum == (r.stops.length * (r.stops.length + 1)) / 2 }
      end
    end
  end

  test 'should automatic insert taking into account only active or all stops' do
    customers(:customer_one).update(job_optimizer_id: nil)
    Vehicle.all.each{ |v| v.update tags: [] }

    # 0. Init all stops inactive
    @planning.routes.each{ |r| r.stops.each{ |s| s.update! active: false } }
    @planning.reload
    unassigned_stop = @planning.routes.detect{ |route| !route.vehicle_usage }.stops.select(&:position?).first

    # 1. First insert with active_only = true
    patch api("#{@planning.id}/automatic_insert"), nil, input: { stop_ids: [unassigned_stop.id], out_of_zone: true, active_only: false }.to_json, CONTENT_TYPE: 'application/json'
    assert_equal 204, last_response.status
    assert @planning.routes.reload.select(&:vehicle_usage).any?{ |route| route.stop_ids.include?(unassigned_stop.id) }

    stop = @planning.routes.flat_map{ |r| r.stops.select{ |s| s.id == unassigned_stop.id } }.compact.first
    stop_compare = [stop.route_id, stop.index]

    # 2. Move back stop to original route
    @planning.move_stop(@planning.routes.detect{ |route| !route.vehicle_usage }, stop, nil)
    @planning.routes.each{ |r| r.compute && r.save! }
    @planning.save!

    # 3. Init all stops active
    @planning.routes.each{ |r| r.stops.each{ |s| s.update! active: true } }
    @planning.reload
    unassigned_stop = @planning.reload.routes.detect{ |route| !route.vehicle_usage }.stops.select(&:position?).first

    # 4. Second insert with active_only = false
    patch api("#{@planning.id}/automatic_insert"), nil, input: { stop_ids: [unassigned_stop.id], out_of_zone: true, active_only: true }.to_json, CONTENT_TYPE: 'application/json'
    assert_equal 204, last_response.status
    assert @planning.routes.reload.select(&:vehicle_usage).any?{ |route| route.stop_ids.include?(unassigned_stop.id) }

    # 5. Route or index should be different between automatic insert
    stop = @planning.routes.flat_map{ |r| r.stops.select{ |s| s.id == unassigned_stop.id } }.compact.first
    assert_not_equal stop_compare, [stop.route_id, stop.index]
  end

  test 'should automatic insert or not with max time' do
    customers(:customer_one).update(job_optimizer_id: nil)
    unassigned_stop = @planning.routes.detect{ |route| !route.vehicle_usage }.stops.select(&:position?).first

    patch api("#{@planning.id}/automatic_insert"), nil, input: { stop_ids: [unassigned_stop.id], max_time: 60 }.to_json, CONTENT_TYPE: 'application/json'
    assert_equal 400, last_response.status
    assert_not @planning.routes.reload.select(&:vehicle_usage).any?{ |route| route.stop_ids.include?(unassigned_stop.id)}

    # Regarding the stub the insertion detour is 60
    patch api("#{@planning.id}/automatic_insert"), nil, input: { stop_ids: [unassigned_stop.id], max_time: 61 }.to_json, CONTENT_TYPE: 'application/json'
    assert_equal 204, last_response.status
    assert @planning.routes.reload.select(&:vehicle_usage).any?{ |route| route.stop_ids.include?(unassigned_stop.id) }
  end

  test 'should automatic insert or not with max distance' do
    customers(:customer_one).update(job_optimizer_id: nil)
    unassigned_stop = @planning.routes.detect{ |route| !route.vehicle_usage }.stops.select(&:position?).first
    # Fixtures route time and distance are 1.5 (and should be updated)
    @planning.routes.each{ |r| r.outdated = true }

    patch api("#{@planning.id}/automatic_insert"), nil, input: { stop_ids: [unassigned_stop.id], max_distance: 500}.to_json, CONTENT_TYPE: 'application/json'
    assert_equal 400, last_response.status
    assert_not @planning.routes.reload.select(&:vehicle_usage).any?{ |route| route.stop_ids.include?(unassigned_stop.id)}

    # Regarding the stub the insertion detour is 1000
    patch api("#{@planning.id}/automatic_insert"), nil, input: { stop_ids: [unassigned_stop.id], max_distance: 1_001}.to_json, CONTENT_TYPE: 'application/json'
    assert_equal 204, last_response.status
    assert @planning.routes.reload.select(&:vehicle_usage).any?{ |route| route.stop_ids.include?(unassigned_stop.id) }
  end

  test 'should automatic insert with error' do
    customers(:customer_one).update(job_optimizer_id: nil)
    Route.stub_any_instance(:compute, lambda{ |*a| raise }) do
      unassigned_stop = @planning.routes.detect{ |route| !route.vehicle_usage }.stops.select(&:position?).first
      assert_no_difference('Stop.count') do
        patch api("#{@planning.id}/automatic_insert"), nil, input: { stop_ids: [unassigned_stop.id], out_of_zone: true }.to_json, CONTENT_TYPE: 'application/json'
        assert_equal 500, last_response.status
        assert @planning.routes.reload.detect{ |route| !route.vehicle_usage }.stop_ids.include?(unassigned_stop.id)
      end
    end
  end

  test 'should apply order array to planning' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      order_array = order_arrays :order_array_one
      planning = plannings :planning_one
      assert !planning.order_array
      patch api("#{planning.id}/order_array", order_array_id: order_array.id, shift: 0)
      if mode
        assert_equal 409, last_response.status, last_response.body
      else
        assert_equal 200, last_response.status, last_response.body
        assert_equal order_array, planning.reload.order_array
      end
    end
  end

  test 'should update routes' do
    customers(:customer_one).update job_optimizer_id: nil
    planning = plannings :planning_one
    route = routes :route_one_one

    without_loading Stop do
      patch api("#{planning.id}/update_routes"), { route_ids: [route.id], selection: 'none', action: 'toggle' }
      assert last_response.ok?
      assert_equal true, JSON.parse(last_response.body)[0]['hidden']
      patch api("#{planning.id}/update_routes"), { route_ids: [route.id], selection: 'reverse', action: 'toggle' }
      assert_equal false, JSON.parse(last_response.body)[0]['hidden']

      patch api("#{planning.id}/update_routes"), { route_ids: [route.id], selection: 'all', action: 'lock' }
      assert last_response.ok?
      assert_equal true, JSON.parse(last_response.body)[0]['locked']
      patch api("#{planning.id}/update_routes"), { route_ids: [route.id], selection: 'reverse', action: 'lock' }
      assert_equal false, JSON.parse(last_response.body)[0]['locked']
    end
  end

  test 'should raise exceptions if job already in progress' do
    customers(:customer_one).update job_optimizer_id: nil
    planning = plannings(:planning_one)
    Job.expects(:on_planning).with(planning.customer.job_optimizer, planning.id).returns(true)
    route = routes(:route_one_one)

    without_loading Stop do
      patch api("#{planning.id}/update_routes"), { route_ids: [route.id], selection: 'none', action: 'toggle' }
      assert_equal 409, last_response.status
    end
  end

  test 'should apply zonings' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      get api("/#{@planning.id}/apply_zonings", { details: true })
      assert_equal mode ? 409 : 200, last_response.status, last_response.body
    end
  end

  test 'should optimize each route' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      [false, true].each do |sync|
        get api("/#{@planning.id}/optimize", { details: true, synchronous: sync })
        assert_equal mode ? 409 : sync ? 200 : 204, last_response.status, last_response.body
      end
    end
  end

  test 'should perform a global optimization' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      [false, true].each do |sync|
        get api("/#{@planning.id}/optimize", { global: true, details: true, synchronous: sync })
        assert_equal mode ? 409 : sync ? 200 : 204, last_response.status, last_response.body
      end
    end
  end

  test 'should optimize all stops in routes' do
    [:during_optimization, nil].each do |mode|
      customers(:customer_one).update(job_optimizer_id: nil) if mode.nil?
      [false, true].each do |all|
        get api("/#{@planning.id}/optimize", {details: true, active_only: all })
        assert_equal mode ? 409 : 204, last_response.status, last_response.body
      end
    end
  end

  test 'should not optimize when a false planning\'s id is given' do
    customers(:customer_one).update(job_optimizer_id: nil)
    planning_false_id = Random.new_seed
    [false, true].each do |sync|
      get api("/#{planning_false_id}/optimize", {details: true, synchronous: sync })
      assert_equal 404, last_response.status
    end
  end

  test 'should return a 404 error' do
    planning = plannings(:planning_one)
    patch "api/0.1/plannings/#{planning.id.to_s}/routes/none/visits/moves.json?api_key=testkey1&visit_ids=47,48"
    assert_equal  404, last_response.status
  end

  test 'should return plannings in any case' do
    planning2 = plannings :planning_two
    ['ics', 'json', 'xml'].each do |ext|
      [nil, "#{@planning.id},#{planning2.id}", "ref:#{@planning.ref},ref:#{planning2.ref}"].each do |params|
        get "api/0.1/plannings.#{ext}?api_key=testkey1" + (params ? "&ids=#{params}" : '')
        assert last_response.ok?, last_response.body
        if (ext == 'json')
          response = JSON.parse(last_response.body)
          assert_equal 2, response.count
        elsif (ext == 'xml')
          response = last_response.body
          assert_equal 2, response.scan('<id type="integer">').count
        elsif (ext == 'ics')
          response = last_response.body
          stop_count = customers(:customer_one).plannings.flat_map{ |p| p.routes.select(&:vehicle_usage).map{ |r| r.stops.select(&:active?).select(&:position?).select(&:time?).size } }.reduce(&:+)
          assert_equal stop_count, response.scan('BEGIN:VEVENT').count
        end
      end
    end
  end

  test 'should return a 204 header when email=true' do
    get "api/0.1/plannings.ics?api_key=testkey1&ids=1&email=true"
    assert_equal 204, last_response.status
  end

  test 'should update stops status' do
    planning = plannings :planning_one

    patch api("#{planning.id}/update_stops_status")
    assert_equal 204, last_response.status

    customers(:customer_one).update(job_optimizer_id: nil)

    patch api("#{planning.id}/update_stops_status")
    assert_equal 204, last_response.status

    patch api("#{planning.id}/update_stops_status", details: true)
    assert_equal 200, last_response.status
  end

  test 'should return a planning with deprecated attributes' do
    @planning.zoning_outdated = true
    @planning.routes[0].outdated = true
    @planning.save!

    get api(@planning.id)
    assert last_response.ok?, last_response.body
    json = JSON.parse(last_response.body)
    assert json['zoning_outdated']
    assert json['zoning_out_of_date']
    assert json['outdated']
    assert json['out_of_date']
  end

  test 'should use limitation' do
    customer = @planning.customer
    customer.delete_all_plannings
    customer.max_plannings = 1
    customer.save!

    assert_difference('Planning.count', 1) do
      post api(), @planning.attributes.merge({tag_operation: 'and'})
      assert last_response.created?, last_response.body
    end

    assert_difference('Planning.count', 0) do
      assert_difference('Route.count', 0) do
        post api(), @planning.attributes.merge({tag_operation: 'and'})
        assert last_response.forbidden?, last_response.body
        assert_equal 'dépassement du nombre maximal de plans', JSON.parse(last_response.body)['message']
      end
    end
  end

  test 'should send SMS for each stop visit' do
    @planning.customer.reseller.update(messagings: {sms_partner: { enable: true, api_key: :sms_api_key, api_secret: :sms_api_secret }})
    @planning.customer.update enable_sms: true

    SmsPartnerService.stub_any_instance(:send_message, true) do
      get api("#{@planning.id}/send_sms")
      assert last_response.ok?, 'Bad response: ' + last_response.body
      assert_equal '4', last_response.body
    end
  end

  test 'should send SMS to mobile only' do
    @planning.customer.reseller.update(messagings: {sms_partner: { enable: true, api_key: :sms_api_key, api_secret: :sms_api_secret }})
    @planning.customer.update enable_sms: true
    @planning.customer.destinations.first(2).each {|d| d.update_attribute(:phone_number, '0612345678')}

    SmsPartnerService.stub_any_instance(:send_message, ->(to, _ct, _opts) { true if to == '0612345678' }) do
      get api("#{@planning.id}/send_sms")
      assert last_response.ok?, 'Bad response: ' + last_response.body
      assert_equal '2', last_response.body
    end
  end

  test 'should return ok response even if no sms is sent' do
    @planning.customer.reseller.update(messagings: {sms_partner: { enable: true, api_key: :sms_api_key, api_secret: :sms_api_secret }})
    @planning.customer.update enable_sms: true

    SmsPartnerService.stub_any_instance(:send_message, false) do
      get api("#{@planning.id}/send_sms")
      assert last_response.ok?, 'Bad response: ' + last_response.body
      assert_equal '0', last_response.body
    end
  end

  test 'should get planning quantities' do
    get api("#{@planning.id}/quantities")
    assert last_response.ok?
    assert_equal 0, JSON.parse(last_response.body).count
  end

  test 'should get vehicule_usages of a whole planning' do
    get api("#{@planning.id}/vehicle_usages")
    assert last_response.ok?
    assert_equal 2, JSON.parse(last_response.body).count
  end
end

class V01::PlanningsErrorTest < V01::PlanningsBaseTest

  test 'should perform a global optimization and return no solution found' do
    customers(:customer_one).update(job_optimizer_id: nil)
    OptimizerWrapper.stub_any_instance(:optimize, lambda{ |*_a| raise VRPNoSolutionError.new }) do
      get api("/#{@planning.id}/optimize", { global: true, details: true, synchronous: true })
      assert_equal 304, last_response.status, last_response.body
    end
  end
end

class V01::PlanningTestException < V01::PlanningsBaseTest

  test 'should not apply zonings because of router exception' do
    assert_no_difference('Stop.count') do
      get api("/#{plannings(:planning_one).id}/apply_zonings", details: true)
      assert_equal 409, last_response.status
    end
  end

end
