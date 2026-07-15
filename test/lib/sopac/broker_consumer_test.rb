# frozen_string_literal: true

require 'test_helper'

class SopacBroker::BrokerConsumerTest < ActiveSupport::TestCase
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
    @consumer = SopacBroker::BrokerConsumer.new
    @config = SopacBroker::BrokerConfig.for_customer(@customer)
  end

  test 'stop halts the consumer loop' do
    @consumer.stop

    assert_equal false, @consumer.instance_variable_get(:@running)
  end

  test 'sync_subscriptions subscribes enabled customer' do
    connection = mock('connection')
    channel = mock('channel')
    queue = mock('queue')
    delivery = mock('delivery')
    delivery.stubs(:delivery_tag).returns(42)

    SopacBroker::BrokerConnection.stubs(:connect).with(@config).returns(connection)
    connection.stubs(:create_channel).returns(channel)
    connection.stubs(:open?).returns(true)
    channel.stubs(:prefetch)
    channel.stubs(:open?).returns(true)
    channel.stubs(:queue).returns(queue)
    channel.stubs(:ack)
    queue.stubs(:subscribe).yields(delivery, {}, '{}').returns('consumer-tag')
    SopacBroker::MessageHandlers::Measurement.stubs(:call)

    Customer.stubs(:find_each).yields(@customer)

    @consumer.send(:sync_subscriptions)

    assert @consumer.instance_variable_get(:@subscriptions).key?(@customer.id)
  end

  test 'sync_subscriptions tears down customer when sopac is disabled' do
    subscriptions = {
      @customer.id => SopacBroker::BrokerConsumer::Subscription.new(
        connection: mock('connection', open?: false),
        queue_subscriptions: []
      )
    }
    @consumer.instance_variable_set(:@subscriptions, subscriptions)

    disabled_customer = @customer
    disabled_customer.stubs(:devices).returns({ sopac: { enable: 'false' } })
    SopacBroker::BrokerConfig.stubs(:customer_enabled?).with(disabled_customer).returns(false)

    Customer.stubs(:find_each).yields(disabled_customer)

    @consumer.send(:sync_subscriptions)

    assert_empty @consumer.instance_variable_get(:@subscriptions)
  end
end
