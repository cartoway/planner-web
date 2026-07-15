# frozen_string_literal: true

require 'test_helper'

class SopacBroker::CacheTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
    @store = ActiveSupport::Cache::MemoryStore.new
    @cache = SopacBroker::Cache.new(@customer.id, store: @store)
  end

  test 'write_measurement stores payload and registers device label' do
    data = { 'id' => '238B019C', 'label' => 'Logger 1', 'm' => [] }

    @cache.write_measurement('238B019C', data)

    assert_equal data, @cache.read_measurement('238B019C')
    assert_equal 'Logger 1', @cache.devices_registry['238B019C']['label']
  end

  test 'write_measurement links logger to latest hub from measurements' do
    data = {
      'id' => '238B019C',
      'm' => [
        { 'utc' => 100, 'hub' => 'hub-old' },
        { 'utc' => 200, 'hub' => 'hub-new' }
      ]
    }

    @cache.write_measurement('238B019C', data)

    assert_equal 'hub-new', @cache.read_logger_hub('238B019C')
  end

  test 'write_measurement uses vrn as registry label when label is missing' do
    @cache.write_measurement('ABC', { 'id' => 'ABC', 'vrn' => 'VRN-42', 'm' => [] })

    assert_equal 'VRN-42', @cache.devices_registry['ABC']['label']
  end

  test 'write_hub and write_hub_gps round-trip through the store' do
    hub = { 'id' => '0000181B', 'status' => 'online' }
    gps = { 'id' => '0000181B', 'lat' => 44.5, 'lon' => 11.3, 'deviceTime' => 1_723_449_597 }

    @cache.write_hub('0000181B', hub)
    @cache.write_hub_gps('0000181B', gps)

    assert_equal hub, @cache.read_hub('0000181B')
    assert_equal gps, @cache.read_hub_gps('0000181B')
  end

  test 'devices_registry returns empty hash when unset' do
    assert_equal({}, @cache.devices_registry)
  end
end
