require 'test_helper'

class V01::VehicleUsageSetsTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include ActionDispatch::TestProcess

  def app
    Rails.application
  end

  setup do
    @customer = customers(:customer_one)
    @vehicle_usage_set = vehicle_usage_sets(:vehicle_usage_set_one)
  end

  def around
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1000, 60, '_ibE_seK_seK_seK'] } } ) do
      yield
    end
  end

  def api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/vehicle_usage_sets#{part}.json?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  test 'should return customer''s vehicle_usage_sets' do
    get api()
    assert last_response.ok?, last_response.body
    assert_equal @vehicle_usage_set.customer.vehicle_usage_sets.size, JSON.parse(last_response.body).size
  end

  test 'should return customer''s vehicle_usage_sets by ids' do
    get api(nil, 'ids' => @vehicle_usage_set.id)
    assert last_response.ok?, last_response.body
    assert_equal 1, JSON.parse(last_response.body).size
    assert_equal @vehicle_usage_set.id, JSON.parse(last_response.body)[0]['id']
  end

  test 'should return a vehicle_usage_set' do
    get api(@vehicle_usage_set.id)
    assert last_response.ok?, last_response.body
    assert_equal @vehicle_usage_set.name, JSON.parse(last_response.body)['name']
  end

  test 'should create a vehicle_usage_set' do
    assert_difference('VehicleUsageSet.count', 1) do
      @vehicle_usage_set.name = 'new name'
      @vehicle_usage_set.max_distance = 60
      post api(), @vehicle_usage_set.attributes
      assert last_response.created?, last_response.body
    end
  end

  test 'should create a vehicle_usage_set with max ride distance/time' do
    assert_difference('VehicleUsageSet.count', 1) do
      @vehicle_usage_set.name = 'new name'
      @vehicle_usage_set.max_ride_distance = 5
      @vehicle_usage_set.max_ride_duration = 6
      post api(), @vehicle_usage_set.attributes
      result = JSON.parse(last_response.body)
      assert last_response.created?, last_response.body
      assert_equal 5, result['max_ride_distance']
      assert_equal '00:00:06', result['max_ride_duration']
    end
  end

  test 'should update a vehicle_usage_set' do
    @vehicle_usage_set.name = 'new name'
    put api(@vehicle_usage_set.id), name: 'riri', max_distance: 60, max_ride_distance: 7, max_ride_duration: '00:08'
    assert last_response.ok?, last_response.body

    get api(@vehicle_usage_set.id)
    result = JSON.parse(last_response.body)
    assert last_response.ok?, last_response.body
    assert_equal 'riri', result['name']
    assert_equal 60, result['max_distance']
    assert_equal 7, result['max_ride_distance']
    assert_equal '00:08:00', result['max_ride_duration']
  end

  test 'should update a vehicle_usage_set store with null value' do
    put api(@vehicle_usage_set.id), store_start_id: nil, store_stop_id: nil, store_rest_id: nil, max_distance: nil
    assert last_response.ok?, last_response.body

    get api(@vehicle_usage_set.id)
    assert last_response.ok?, last_response.body
    assert_nil JSON.parse(last_response.body)['store_start_id']
    assert_nil JSON.parse(last_response.body)['store_stop_id']
    assert_nil JSON.parse(last_response.body)['store_rest_id']
  end

  test 'should destroy a vehicle_usage_set' do
    assert_difference('VehicleUsageSet.count', -1) do
      delete api(@vehicle_usage_set.id)
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should destroy multiple vehicle_usage_sets' do
    assert_difference('VehicleUsageSet.count', -1) do
      delete api + "&ids=#{vehicle_usage_sets(:vehicle_usage_set_one).id}"
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'should import vehicle usage set from csv without replacing vehicles' do
    @customer.vehicle_usage_sets.reject{ |vu| vu == @vehicle_usage_set }.each(&:destroy)
    @customer.update_attribute(:max_vehicle_usage_sets, 1)
    @customer.reload

    assert_difference('VehicleUsageSet.count', 0) do
      put api(), replace_vehicles: false, file: fixture_file_upload(Rails.root.join('test/fixtures/files/import_vehicle_usage_sets_one.csv'), 'text/csv')
      assert last_response.ok?, last_response.body
      json = JSON.parse(last_response.body)

      assert_equal '001', json[0]['ref']
      assert_not_equal 'Véhicule 1', json[0]['name']
      assert_equal '08:00:00', json[0]['vehicle_usages'][0]['time_window_start']
      assert_equal '16:00:00', json[0]['vehicle_usages'][0]['time_window_end']
    end
  end

  test 'should import vehicle usage set from csv and replace vehicles' do
    @customer.update_attribute(:max_vehicle_usage_sets, 6)

    assert_difference('VehicleUsageSet.count', 1) do
      put api(), replace_vehicles: true, file: fixture_file_upload('files/import_vehicle_usage_sets_one.csv', 'text/csv')
      assert last_response.ok?, last_response.body
      json = JSON.parse(last_response.body)

      assert_equal 'Véhicule 1', json[0]['name']
      assert_equal 'vehicle1@example.com', json[0]['contact_email']
      assert_equal 10, json[0]['consumption']
      assert_equal '08:00:00', json[0]['vehicle_usages'][2]['time_window_start']
      assert_equal '16:00:00', json[0]['vehicle_usages'][2]['time_window_end']

      assert_equal 'Véhicule 2', json[1]['name']
      assert_equal 'vehicle2@example.com', json[1]['contact_email']
      assert_equal 15, json[1]['consumption']
      assert_nil json[1]['vehicle_usages'][2]['time_window_start']
      assert_equal '16:00:00', json[1]['vehicle_usages'][2]['time_window_end']

      assert_equal 64800, @customer.vehicle_usage_sets.last.time_window_end
    end
  end

  test 'should use limitation' do
    customer = @vehicle_usage_set.customer
    customer.max_vehicle_usage_sets = customer.vehicle_usage_sets.count + 1
    customer.save!

    assert_difference('VehicleUsageSet.count', 1) do
      post api(), @vehicle_usage_set.attributes
      assert last_response.created?, last_response.body
    end

    assert_difference('VehicleUsageSet.count', 0) do
      assert_difference('VehicleUsage.count', 0) do
        post api(), @vehicle_usage_set.attributes
        assert last_response.forbidden?, last_response.body
        assert_equal 'dépassement du nombre maximal de configurations des véhicules', JSON.parse(last_response.body)['message']
      end
    end
  end
end
