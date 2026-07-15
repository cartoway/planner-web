# frozen_string_literal: true

require 'test_helper'

class SopacBroker::BrokerConnectionTest < ActiveSupport::TestCase
  setup do
    @config = {
      host: 'rabbit.example.com',
      vhost: 'blu-vhost',
      username: 'broker_user',
      password: 'broker_pass',
      queue_names: {
        measurements: '/SOPAC/CARTOWAY/measurements',
        hubs: '/SOPAC/CARTOWAY/hubs',
        hubs_gps: '/SOPAC/CARTOWAY/hubs-gps'
      }
    }
  end

  test 'connect raises when broker configuration is incomplete' do
    error = assert_raises(DeviceServiceError) do
      SopacBroker::BrokerConnection.connect(@config.merge(username: nil))
    end
    assert_match(/incomplete/, error.message)
  end

  test 'verify! requires measurements queue to exist' do
    SopacBroker::BrokerConnection.stubs(:diagnose).returns([
      { resource: 'queue', name: @config[:queue_names][:measurements], ok: false, error: 'NOT_FOUND' }
    ])

    error = assert_raises(DeviceServiceError) do
      SopacBroker::BrokerConnection.verify!(@config)
    end
    assert_match(/required queue not found/, error.message)
  end

  test 'verify! succeeds when measurements queue exists' do
    SopacBroker::BrokerConnection.stubs(:diagnose).returns([
      { resource: 'queue', name: @config[:queue_names][:measurements], ok: true },
      { resource: 'queue', name: @config[:queue_names][:hubs], ok: false, error: 'NOT_FOUND' }
    ])

    assert_nothing_raised do
      SopacBroker::BrokerConnection.verify!(@config)
    end
  end

  test 'probe reports queue metadata on success' do
    channel = mock('channel')
    queue = mock('queue')
    queue.stubs(:message_count).returns(3)
    queue.stubs(:consumer_count).returns(1)
    channel.expects(:queue).with('queue-name', passive: true).returns(queue)

    result = SopacBroker::BrokerConnection.probe(channel, resource: :queue, name: 'queue-name', label: 'measurements')

    assert result[:ok]
    assert_equal 3, result[:messages]
    assert_equal 1, result[:consumers]
  end

  test 'probe reports NOT_FOUND when queue is missing' do
    channel = mock('channel')
    channel.expects(:queue).raises(Bunny::NotFound.new('queue missing', nil, nil))

    result = SopacBroker::BrokerConnection.probe(channel, resource: :queue, name: 'missing', label: 'hubs')

    assert_not result[:ok]
    assert_equal 'NOT_FOUND', result[:error]
  end
end
