# frozen_string_literal: true

require 'test_helper'

class SopacTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
    @customer.update!(
      devices: {
        sopac: {
          enable: 'true',
          username: 'broker_user',
          password: 'broker_pass',
          queue_prefix: '/SOPAC/CARTOWAY'
        }
      }
    )
    @customer.vehicles.first.update!(devices: { sopac_ids: ['238B019C'] })
    @service = Planner::Application.config.devices.sopac
    @store = ActiveSupport::Cache::MemoryStore.new
    Planner::Application.config.devices.stubs(:sopac_cache_object).returns(@store)
  end

  test 'list_devices bootstraps registry when empty' do
    SopacBroker::RegistryBootstrap.expects(:call).with(@customer)
    @service.list_devices(@customer)
  end

  test 'list_devices reads devices registry from cache' do
    SopacBroker::RegistryBootstrap.expects(:call).with(@customer)
    cache = SopacBroker::Cache.new(@customer.id, store: @store)
    cache.write_measurement('238B019C', { 'id' => '238B019C', 'label' => 'Logger 1', 'm' => [] })

    devices = @service.list_devices(@customer)
    assert_equal 1, devices.size
    assert_equal '238B019C', devices.first[:id]
    assert_equal 'Logger 1', devices.first[:text]
  end

  test 'vehicles_temperature reads latest measurement from cache' do
    cache = SopacBroker::Cache.new(@customer.id, store: @store)
    cache.write_measurement('238B019C', {
      'id' => '238B019C',
      'label' => 'Logger 1',
      'm' => [{ 't' => 7.2, 'h' => 55.0, 'utc' => 1_501_688_218_000 }]
    })

    result = @service.vehicles_temperature(@customer)
    assert_equal 1, result.size
    info = result.first[:device_infos].first
    assert_in_delta 7.2, info[:temperature].to_f
    assert_equal '238B019C', info[:device_id]
  end

  test 'vehicle_pos prefers hub gps over hub status' do
    cache = SopacBroker::Cache.new(@customer.id, store: @store)
    cache.write_measurement('238B019C', {
      'id' => '238B019C',
      'm' => [{ 'utc' => 1, 'hub' => '0000181B' }]
    })
    cache.write_hub('0000181B', { 'id' => '0000181B', 'lat' => 1.0, 'lon' => 2.0, 'lastSeen' => '2024-01-01T00:00:00Z' })
    cache.write_hub_gps('0000181B', {
      'id' => '0000181B',
      'lat' => 44.5,
      'lon' => 11.3,
      'deviceTime' => 1_723_449_597,
      'speed' => 1000,
      'course' => 9000
    })

    positions = @service.vehicle_pos(@customer)
    assert_equal 1, positions.size
    assert_in_delta 44.5, positions.first[:lat]
    assert_in_delta 100.0, positions.first[:speed]
    assert_in_delta 90.0, positions.first[:direction]
  end

  test 'check_auth verifies broker connection from request credentials' do
    SopacBroker::BrokerConnection.expects(:verify!).with do |config|
      config[:username] == 'broker_user' &&
        config[:queue_names][:measurements] == '/SOPAC/CARTOWAY/measurements'
    end
    @service.check_auth(
      id: @customer.id,
      username: 'broker_user',
      password: 'broker_pass',
      queue_prefix: 'SOPAC/CARTOWAY'
    )
  end
end
