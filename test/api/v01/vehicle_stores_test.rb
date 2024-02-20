require 'test_helper'

class V01::VehicleStoresTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include ActionDispatch::TestProcess
  set_fixture_class delayed_jobs: Delayed::Backend::ActiveRecord::Job

  def app
    Rails.application
  end

  setup do
    @store = stores(:store_one)
  end

  def api_vehicle_store(param = {})
    part = part ? '/' + part.to_s : ''
    '/api/0.1/import_vehicle_stores.json?api_key=testkey1&' + param.collect{ |k, v| "#{k}=#{v}" }.join('&')
  end

  test 'should create bulk from json' do
    @store.customer.plannings.each(&:destroy)
    @store.customer.reload
    @store.customer.vehicle_usage_sets[1..-1].each(&:destroy) if @store.customer.vehicle_usage_sets.size > 1

    assert_difference('Store.count', 100) do
      assert_difference('Vehicle.count', 98) do
        put api_vehicle_store(), {stores: (0..99).collect{ |i|
          {
            name: 'Nouveau dépôt',
            street: nil,
            postalcode: nil,
            city: 'Tule',
            lat: 43.5710885456786,
            lng: 3.89636993408203,
            ref: '00' + i.to_s,
            geocoding_accuracy: nil,
            foo: 'bar',
            speed_multiplicator: 0.8,
            capacities: [{deliverable_unit_id: deliverable_units(:deliverable_unit_one_one).id, quantity: 10}]
          }
        }}
        assert last_response.ok?, 'Bad response: ' + last_response.body
        json = JSON.parse(last_response.body)
        assert_equal 100, json.size

        @store.customer.reload
        assert_equal 0.8, @store.customer.vehicles[0].speed_multiplier
        assert_equal 10, @store.customer.vehicles[0].capacities.values[0]
      end
    end
  end

  test 'should no create bulk from json when many vehicle_usage_sets are present' do
    assert @store.customer.vehicle_usage_sets.size > 1

    put api_vehicle_store(), {stores: [{
      name: 'Nouveau dépôt',
      street: nil,
      postalcode: nil,
      city: 'Tule',
      lat: 43.5710885456786,
      lng: 3.89636993408203,
      ref: nil,
      geocoding_accuracy: nil,
      foo: 'bar'
    }]}
    assert_equal 422, last_response.status, last_response.body
  end
end
