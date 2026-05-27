# frozen_string_literal: true

# Copyright © Cartoway, 2026
#
# This file is part of Cartoway Planner.
#
# Cartoway Planner is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoway Planner. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#

require_relative 'broker_config'
require_relative 'broker_connection'
require_relative 'cache'
require_relative 'message_handlers/measurement'
require_relative 'message_handlers/hub'
require_relative 'message_handlers/hub_gps'

module SopacBroker
  class BrokerConsumer
    REFRESH_INTERVAL = 300

    QueueSubscription = Struct.new(:channel, :consumer_tag, keyword_init: true)
    Subscription = Struct.new(:connection, :queue_subscriptions, keyword_init: true)

    def initialize
      @subscriptions = {}
      @running = true
    end

    def run
      trap('TERM') { stop }
      trap('INT') { stop }

      Rails.logger.info('[SopacBroker::BrokerConsumer] starting')
      sync_subscriptions

      while @running
        sleep REFRESH_INTERVAL
        sync_subscriptions if @running
      end
    ensure
      teardown_all
      Rails.logger.info('[SopacBroker::BrokerConsumer] stopped')
    end

    def stop
      @running = false
    end

    private

    def sync_subscriptions
      active_ids = Set.new

      Customer.find_each do |customer|
        next unless BrokerConfig.customer_enabled?(customer)

        config = BrokerConfig.for_customer(customer)
        next unless BrokerConfig.valid?(config)

        active_ids << customer.id
        next if @subscriptions.key?(customer.id)

        subscribe_customer(customer, config)
      end

      (@subscriptions.keys - active_ids.to_a).each { |id| teardown_customer(id) }
    end

    def subscribe_customer(customer, config)
      connection = BrokerConnection.connect(config)
      queue_subscriptions = []

      queue_handlers = {
        config[:queue_names][:measurements] => MessageHandlers::Measurement,
        config[:queue_names][:hubs] => MessageHandlers::Hub,
        config[:queue_names][:hubs_gps] => MessageHandlers::HubGps
      }

      queue_handlers.each do |queue_name, handler|
        queue_subscriptions << subscribe_queue(connection, customer.id, queue_name, handler)
      end

      queue_subscriptions.compact!
      if queue_subscriptions.empty?
        connection.close if connection.open?
        Rails.logger.error(
          "[SopacBroker::BrokerConsumer] no queues available for customer #{customer.id} " \
          "(prefix #{config[:queue_names].values.first&.split('/')&.slice(0, 3)&.join('/')})"
        )
        return
      end

      @subscriptions[customer.id] = Subscription.new(
        connection: connection,
        queue_subscriptions: queue_subscriptions
      )
      Rails.logger.info(
        "[SopacBroker::BrokerConsumer] subscribed customer #{customer.id} " \
        "(#{queue_subscriptions.size} queue(s))"
      )
    rescue StandardError => e
      connection&.close if connection&.open?
      Rails.logger.error("[SopacBroker::BrokerConsumer] failed to subscribe customer #{customer.id}: #{e.message}")
    end

    def subscribe_queue(connection, customer_id, queue_name, handler)
      channel = connection.create_channel
      channel.prefetch(1)
      tag = channel.queue(queue_name, passive: true).subscribe(manual_ack: true) do |delivery, _properties, body|
        handler.call(customer_id, body)
        channel.ack(delivery.delivery_tag)
      rescue StandardError => e
        Rails.logger.error("[SopacBroker::BrokerConsumer] #{queue_name} handler error: #{e.message}")
        channel.nack(delivery.delivery_tag, false, true)
      end
      QueueSubscription.new(channel: channel, consumer_tag: tag)
    rescue Bunny::NotFound
      channel.close if channel&.open?
      Rails.logger.warn("[SopacBroker::BrokerConsumer] queue not found, skipping: #{queue_name}")
      nil
    rescue StandardError => e
      channel.close if channel&.open?
      Rails.logger.error("[SopacBroker::BrokerConsumer] failed to subscribe #{queue_name}: #{e.message}")
      nil
    end

    def teardown_customer(customer_id)
      subscription = @subscriptions.delete(customer_id)
      return unless subscription

      subscription.queue_subscriptions.each do |qs|
        qs.channel.cancel(qs.consumer_tag) if qs.channel.open?
      rescue StandardError
        nil
      end
      subscription.queue_subscriptions.each do |qs|
        qs.channel.close if qs.channel.open?
      rescue StandardError
        nil
      end
      subscription.connection.close if subscription.connection.open?
      Rails.logger.info("[SopacBroker::BrokerConsumer] unsubscribed customer #{customer_id}")
    end

    def teardown_all
      @subscriptions.keys.each { |id| teardown_customer(id) }
    end
  end
end
