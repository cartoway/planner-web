require 'test_helper'

class V01::VehiclesTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1, 1, '_ibE_seK_seK_seK'] } } ) do
      yield
    end
  end

  setup do
    @vehicle = vehicles(:vehicle_one)
  end

  def api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/vehicles#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  def api_admin(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/vehicles#{part}.json?api_key=adminkey&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  def api_deliverables(id, param = {})
    "/api/0.1/vehicles/#{id}/deliverable_units?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  test "should return customer's vehicles" do
    get api()
    assert last_response.ok?, last_response.body
    assert_equal @vehicle.customer.vehicles.size, JSON.parse(last_response.body).size
  end

  test "should return customer's vehicles by ids" do
    get api(nil, 'ids' => @vehicle.id)
    assert last_response.ok?, last_response.body
    assert_equal 1, JSON.parse(last_response.body).size
    assert_equal @vehicle.id, JSON.parse(last_response.body)[0]['id']
  end

  test 'should return a vehicle' do
    get api(@vehicle.id)
    assert last_response.ok?, last_response.body
    assert_equal @vehicle.name, JSON.parse(last_response.body)['name']
  end

  test 'should update a vehicle' do
    @vehicle.name = 'new name'
    @vehicle.max_distance = 60
    @vehicle.max_ride_distance = 50
    @vehicle.max_ride_duration = 40
    put api(@vehicle.id), nil, input: @vehicle.attributes.merge({'capacities' => [{deliverable_unit_id: 1, quantity: 30}]}).to_json, CONTENT_TYPE: 'application/json'
    assert last_response.ok?, last_response.body

    get api(@vehicle.id)
    assert last_response.ok?, last_response.body
    vehicle = JSON.parse last_response.body
    assert_equal @vehicle.name, vehicle['name']
    assert_equal @vehicle.max_distance, vehicle['max_distance']
    assert_equal @vehicle.max_ride_distance, vehicle['max_ride_distance']
    assert_equal @vehicle.max_ride_duration_absolute_time_with_seconds, vehicle['max_ride_duration']
    assert_equal 30, vehicle['capacities'][0]['quantity']
  end

  test 'should update vehicle router options' do
    put api(@vehicle.id), nil, input: {router_options: {motorway: false, weight_per_axle: 3, length: 30, hazardous_goods: 'gas', max_walk_distance: 600, approach: 'curb', snap: 50, low_emission_zone: 'false'}}.to_json, CONTENT_TYPE: 'application/json'
    assert last_response.ok?, last_response.body

    vehicle = JSON.parse(last_response.body)
    # FIXME: replace each assertion by one which checks if hash is included in another
    assert vehicle['router_options']['motorway'] = 'false'
    assert vehicle['router_options']['weight_per_axle'] = '3'
    assert vehicle['router_options']['length'] = '30'
    assert vehicle['router_options']['hazardous_goods'] = 'gas'
    assert vehicle['router_options']['max_walk_distance'] = '600'
    assert vehicle['router_options']['approach'] = 'curb'
    assert vehicle['router_options']['snap'] = '50'
    assert vehicle['router_options']['low_emission_zone'] = 'false'
  end

  test 'should update vehicle with router options containing a comma' do
    put api(@vehicle.id), nil, input: {router_options: {motorway: false, width: '3,55', weight_per_axle: 3, length: 30, hazardous_goods: 'gas', max_walk_distance: 600, approach: 'curb', snap: 50, low_emission_zone: 'false'}}.to_json, CONTENT_TYPE: 'application/json'
    assert last_response.ok?, last_response.body

    vehicle = JSON.parse(last_response.body)
    assert vehicle['router_options']['width'] = 3.55
  end

  test 'should not update vehicle with invalid router options' do
    put api(@vehicle.id), nil, input: {router_options: {motorway: false, width: '3;55', weight_per_axle: 3, length: 30, hazardous_goods: 'gas', max_walk_distance: 600, approach: 'curb', snap: 50, low_emission_zone: 'false'}}.to_json, CONTENT_TYPE: 'application/json'
    errors = JSON.parse(last_response.body)
    assert_equal errors['message'], 'router_options[width] is invalid'
  end

  test 'should update vehicle with capacities or return parse error' do
    put api(@vehicle.id), nil, input: { capacities: [{ deliverable_unit_id: 1, quantity: 10 }] }.to_json, 'CONTENT_TYPE': 'application/json'
    assert last_response.ok?, last_response.body

    vehicle = JSON.parse(last_response.body)
    assert vehicle['capacities'][0]['deliverable_unit_id'], 1
    assert vehicle['capacities'][0]['quantity'], 10

    put api(@vehicle.id), nil, input: { capacities: [{ deliverable_unit: 1, quantity: 'aaa' }] }.to_json, 'CONTENT_TYPE': 'application/json'
    assert last_response.bad_request?
    response = JSON.parse(last_response.body)
    assert_equal response['message'], 'capacities[0][deliverable_unit_id] is missing, capacities[0][quantity] is invalid'
  end

  test 'should create a vehicle' do
    begin
      manage_vehicles_only_admin = Planner::Application.config.manage_vehicles_only_admin
      Planner::Application.config.manage_vehicles_only_admin = false

      customer = customers(:customer_one)

      # test creation and callbacks
      assert_difference('Vehicle.count', 1) do
        assert_difference('VehicleUsage.count', customer.vehicle_usage_sets.length) do
          assert_difference('Route.count', customer.plannings.length) do
            post api, { ref: 'new', name: 'Vh1', time_window_start: '10:00', store_start_id: stores(:store_zero).id, store_stop_id: stores(:store_zero).id, customer_id: customers(:customer_one).id, color: '#bebeef', max_distance: 60, capacities: [{deliverable_unit_id: 1, quantity: 30}], custom_attributes: { foo: true } }, as: :json
            assert last_response.created?, last_response.body
            vehicle = JSON.parse last_response.body
            assert_equal '#bebeef', vehicle['color']
            assert_equal 30, vehicle['capacities'][0]['quantity']
          end
        end
      end
    ensure
      Planner::Application.config.manage_vehicles_only_admin = manage_vehicles_only_admin
    end
  end

  test 'should not create a vehicle' do
    begin
      manage_vehicles_only_admin = Planner::Application.config.manage_vehicles_only_admin
      Planner::Application.config.manage_vehicles_only_admin = true

      assert_no_difference('Vehicle.count') do
        post api, nil, input: { ref: 'new', name: 'Vh1', time_window_start: '10:00', store_start_id: stores(:store_zero).id, store_stop_id: stores(:store_zero).id, customer_id: customers(:customer_one).id, color: '#bebeef', capacities: [{deliverable_unit_id: 1, quantity: 30}] }.to_json, CONTENT_TYPE: 'application/json'

        assert_equal 403, last_response.status, 'Bad response: ' + last_response.body
      end
    ensure
      Planner::Application.config.manage_vehicles_only_admin = manage_vehicles_only_admin
    end
  end

  test 'should create a vehicle with admin key' do
    begin
      manage_vehicles_only_admin = Planner::Application.config.manage_vehicles_only_admin
      Planner::Application.config.manage_vehicles_only_admin = true

      customer = customers(:customer_one)

      # test creation and callbacks
      assert_difference('Vehicle.count', 1) do
        assert_difference('VehicleUsage.count', customer.vehicle_usage_sets.length) do
          assert_difference('Route.count', customer.plannings.length) do
            post api_admin, { ref: 'new', name: 'Vh1', time_window_start: '10:00', store_start_id: stores(:store_zero).id, store_stop_id: stores(:store_zero).id, customer_id: customers(:customer_one).id, color: '#bebeef', capacity: 30 }, as: :json
            assert last_response.created?, last_response.body
            vehicle = JSON.parse last_response.body
            assert_equal '#bebeef', vehicle['color']
            assert_equal 30, vehicle['capacities'][0]['quantity']
          end
        end
      end
    ensure
      Planner::Application.config.manage_vehicles_only_admin = manage_vehicles_only_admin
    end
  end

  test 'should create a vehicle with tag_ids' do
    begin
      manage_vehicles_only_admin = Planner::Application.config.manage_vehicles_only_admin
      Planner::Application.config.manage_vehicles_only_admin = false

      customer = customers(:customer_one)
      tags_str = tags(:tag_one).id.to_s + ',' + tags(:tag_two).id.to_s

      #tag_ids can be string coma separated or array of integer
      [
        [tags(:tag_one).id, tags(:tag_two).id],
        tags_str
      ].each { |tags|
        assert_difference('Vehicle.count', 1) do
          assert_difference('VehicleUsage.count', customer.vehicle_usage_sets.length) do
            assert_difference('Route.count', customer.plannings.length) do
              post api, nil, input: { ref: 'new', name: 'Vh1', time_window_start: '10:00', store_start_id: stores(:store_zero).id, store_stop_id: stores(:store_zero).id, customer_id: customers(:customer_one).id, color: '#bebeef', max_distance: 60, capacities: [{deliverable_unit_id: 1, quantity: 30}], tag_ids: tags }.to_json, CONTENT_TYPE: 'application/json'
              assert last_response.created?, last_response.body
              vehicle = JSON.parse last_response.body
              assert_equal tags_str, vehicle['tag_ids'].join(',')
              assert_equal tags_str, vehicle['vehicle_usages'].first['tag_ids'].join(',')
              assert_equal '#bebeef', vehicle['color']
              assert_equal 30, vehicle['capacities'][0]['quantity']
            end
          end
        end
      }
    ensure
      Planner::Application.config.manage_vehicles_only_admin = manage_vehicles_only_admin
    end
  end

  test 'should create a vehicle with restricted list of custom_attributes' do
    begin
      manage_vehicles_only_admin = Planner::Application.config.manage_vehicles_only_admin
      Planner::Application.config.manage_vehicles_only_admin = false

      customer = customers(:customer_one)
      valid_custom_attribute_names = customer.custom_attributes.map(&:name)
      unknown_custom_attribute_names = ['foo', 'additional']

      custom_attributes = Hash[(valid_custom_attribute_names + unknown_custom_attribute_names).map{ |key| [key, 1] }]

      # test creation and callbacks
      assert_difference('Vehicle.count', 1) do
        assert_difference('VehicleUsage.count', customer.vehicle_usage_sets.length) do
          assert_difference('Route.count', customer.plannings.length) do
            post api, {
              ref: 'new', name: 'Vh1', time_window_start: '10:00', store_start_id: stores(:store_zero).id, store_stop_id: stores(:store_zero).id,
              customer_id: customers(:customer_one).id, color: '#bebeef', max_distance: 60, capacities: [{deliverable_unit_id: 1, quantity: 30}],
              custom_attributes: custom_attributes }, as: :json
            assert last_response.created?, last_response.body
            vehicle = JSON.parse last_response.body
            assert_equal '#bebeef', vehicle['color']
            assert_equal 30, vehicle['capacities'][0]['quantity']
            assert_equal({ "custom_attribute_three"=>"1", "custom_attribute_one"=>1, "custom_attribute_two"=>true }, vehicle['custom_attributes'])
          end
        end
      end
    ensure
      Planner::Application.config.manage_vehicles_only_admin = manage_vehicles_only_admin
    end
  end

  test 'should create a vehicle with time exceeding one day' do
    begin
      manage_vehicles_only_admin = Planner::Application.config.manage_vehicles_only_admin
      Planner::Application.config.manage_vehicles_only_admin = false

      customer = customers(:customer_one)

      # test creation and callbacks
      assert_difference('Vehicle.count', 1) do
        assert_difference('VehicleUsage.count', customer.vehicle_usage_sets.length) do
          assert_difference('Route.count', customer.plannings.length) do
            post api, { ref: 'new', name: 'Vh1', store_start_id: stores(:store_zero).id, store_stop_id: stores(:store_zero).id, customer_id: customers(:customer_one).id, time_window_start: '09:00', time_window_end: '23:00', rest_start: '10:00', rest_stop: '12:00' }, as: :json
            assert last_response.created?, last_response.body
            vehicle = JSON.parse last_response.body
            assert_equal '09:00:00', vehicle['vehicle_usages'][0]['time_window_start']
            assert_equal '23:00:00', vehicle['vehicle_usages'][0]['time_window_end']
            assert_equal '10:00:00', vehicle['vehicle_usages'][0]['rest_start']
            assert_equal '12:00:00', vehicle['vehicle_usages'][0]['rest_stop']

            assert_equal '09:00:00', vehicle['vehicle_usages'][1]['time_window_start']
            assert_equal '23:00:00', vehicle['vehicle_usages'][1]['time_window_end']
            assert_equal '10:00:00', vehicle['vehicle_usages'][1]['rest_start']
            assert_equal '12:00:00', vehicle['vehicle_usages'][1]['rest_stop']
          end
        end
      end
    ensure
      Planner::Application.config.manage_vehicles_only_admin = manage_vehicles_only_admin
    end
  end

  test 'should create and destroy a vehicle' do
    begin
      customer = customers(:customer_one)
      # test with 2 different configs
      manage_vehicles_only_admin = Planner::Application.config.manage_vehicles_only_admin
      [true, false].each { |v|
        Planner::Application.config.manage_vehicles_only_admin = v

        new_name = 'new vehicle'
        # test creation and callbacks
        assert_difference('Vehicle.count', 1) do
          assert_difference('VehicleUsage.count', customer.vehicle_usage_sets.length) do
            assert_difference('Route.count', customer.plannings.length) do
              post v ? api_admin : api, { ref: 'new', name: new_name, time_window_start: '10:00', store_start_id: stores(:store_zero).id, store_stop_id: stores(:store_zero).id, customer_id: customers(:customer_one).id }
              assert last_response.created?, last_response.body
            end
          end
        end

        # test assign attributes
        get api(nil, {ids: 'ref:new'})
        assert last_response.ok?, last_response.body
        assert_equal new_name, JSON.parse(last_response.body)[0]['name']
        id = JSON.parse(last_response.body)[0]['id']
        customer.vehicle_usage_sets.each { |s|
          get "/api/0.1/vehicle_usage_sets/#{s.id.to_s}/vehicle_usages.json?api_key=testkey1"
          hash = JSON.parse(last_response.body)
          u = hash.find{ |u| u['vehicle']['id'] == id }
          assert_equal '10:00:00', u['time_window_start']
          assert_equal stores(:store_zero).id, u['store_start_id']
        }

        # test deletion
        assert_difference('Vehicle.count', -1) do
          assert_difference('VehicleUsage.count', -customer.vehicle_usage_sets.length) do
            assert_difference('Route.count', -customer.plannings.length) do
              delete (v ? api_admin('ref:new') : api('ref:new')) + "&customer_id=#{@vehicle.customer.id}"
              assert_equal 204, last_response.status, last_response.body
            end
          end
        end
      }
    ensure
      Planner::Application.config.manage_vehicles_only_admin = manage_vehicles_only_admin
    end
  end

  test 'should create and destroy multiple vehicles' do
    begin
      customer = customers(:customer_one)
      # test with 2 different configs
      manage_vehicles_only_admin = Planner::Application.config.manage_vehicles_only_admin
      [true, false].each { |v|
        Planner::Application.config.manage_vehicles_only_admin = v

        new_name = 'new vehicle 1'
        post v ? api_admin : api, { ref: 'new1', name: new_name, store_start_id: stores(:store_zero).id, store_stop_id: stores(:store_zero).id, customer_id: customers(:customer_one).id }
        assert last_response.created?, last_response.body
        new_name = 'new vehicle 2'
        post v ? api_admin : api, { ref: 'new2', name: new_name, store_start_id: stores(:store_zero).id, store_stop_id: stores(:store_zero).id, customer_id: customers(:customer_one).id }
        assert last_response.created?, last_response.body

        assert_difference('Vehicle.count', -2) do
          assert_difference('VehicleUsage.count', -2 * customer.vehicle_usage_sets.length) do
            assert_difference('Route.count', -2 * customer.plannings.length) do
              delete (v ? api_admin : api) + "&customer_id=#{@vehicle.customer.id}&ids=ref:new1,ref:new2"
              assert_equal 204, last_response.status, last_response.body
            end
          end
        end
      }
    ensure
      Planner::Application.config.manage_vehicles_only_admin = manage_vehicles_only_admin
    end
  end

  test 'should not destroy a vehicle' do
    begin
      manage_vehicles_only_admin = Planner::Application.config.manage_vehicles_only_admin
      Planner::Application.config.manage_vehicles_only_admin = true

      assert_no_difference('Vehicle.count') do
        delete api("/#{@vehicle.id}")
        assert_equal 403, last_response.status, 'Bad response: ' + last_response.body

        delete api + "&ids=#{vehicles(:vehicle_one).id}"
        assert_equal 403, last_response.status, 'Bad response: ' + last_response.body

        delete api("/#{vehicles(:vehicle_two).id}")
        assert_equal 403, last_response.status, 'Bad response: ' + last_response.body

        delete api_admin("/#{vehicles(:vehicle_two).id}") + "&customer_id=#{@vehicle.customer.id}"
        assert_equal 404, last_response.status, 'Bad response: ' + last_response.body
      end

      Planner::Application.config.manage_vehicles_only_admin = false

      assert_no_difference('Vehicle.count') do
        delete api("/#{vehicles(:vehicle_two).id}")
        assert_equal 404, last_response.status, 'Bad response: ' + last_response.body
      end
    ensure
      Planner::Application.config.manage_vehicles_only_admin = manage_vehicles_only_admin
    end
  end

  test 'should not destroy last vehicle' do
    begin
      manage_vehicles_only_admin = Planner::Application.config.manage_vehicles_only_admin
      [true, false].each { |v|
        Planner::Application.config.manage_vehicles_only_admin = v
        @vehicle.customer.vehicles[0..-2].each{ |vehicle|
          delete (v ? api_admin("/#{vehicle.id}") : api("/#{vehicle.id}")) + "&customer_id=#{@vehicle.customer.id}"
        }
        assert_no_difference('Vehicle.count') do
          vehicle = @vehicle.customer.vehicles[-1]
          delete (v ? api_admin("/#{vehicle.id}") : api("/#{vehicle.id}")) + "&customer_id=#{@vehicle.customer.id}"
          assert last_response.server_error?, last_response.body
        end
      }
    ensure
      Planner::Application.config.manage_vehicles_only_admin = manage_vehicles_only_admin
    end
  end

  test 'should not destroy all vehicles' do
    begin
      manage_vehicles_only_admin = Planner::Application.config.manage_vehicles_only_admin
      [true, false].each { |v|
        Planner::Application.config.manage_vehicles_only_admin = v
        assert_no_difference('Vehicle.count') do
          delete (v ? api_admin() : api) + "&customer_id=#{@vehicle.customer.id}&ids=#{vehicles(:vehicle_one).id},#{vehicles(:vehicle_three).id}"
          assert last_response.server_error?, last_response.body
        end
      }
    ensure
      Planner::Application.config.manage_vehicles_only_admin = manage_vehicles_only_admin
    end
  end

  test 'should update phone number' do
    put api("/#{@vehicle.id}", phone_number: '0578986548')
    assert last_response.ok?
    assert_not_nil @vehicle.reload.phone_number
  end

  test 'Should fetch deliverables by vehicle' do
    get api_deliverables(@vehicle.id, planning_ids: @vehicle.customer.plannings.collect(&:id).join(','))
    assert last_response.ok?, last_response.body
  end

  test 'should create vehicles with rotating color even without the param' do
    customer = customers(:customer_one)
    vehicle_size = customer.vehicles.size
    assert_difference('Vehicle.count', 2) do
      post api, { ref: 'new1', name: 'Vh1', store_start_id: stores(:store_zero).id, store_stop_id: stores(:store_zero).id, customer_id: customers(:customer_one).id }, as: :json
      assert last_response.created?, last_response.body
      vehicle = JSON.parse last_response.body
      assert_equal COLORS_TABLE[vehicle_size], vehicle['color']

      post api, { ref: 'new2', name: 'Vh2', store_start_id: stores(:store_zero).id, store_stop_id: stores(:store_zero).id, customer_id: customers(:customer_one).id }, as: :json
      assert last_response.created?, last_response.body
      vehicle = JSON.parse last_response.body
      assert_equal COLORS_TABLE[vehicle_size + 1], vehicle['color']
    end
  end
end
