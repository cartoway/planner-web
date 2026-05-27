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

require 'test_helper'

class SopacBroker::RegistryBootstrapTest < ActiveSupport::TestCase
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
    @store = ActiveSupport::Cache::MemoryStore.new
    Planner::Application.config.devices.stubs(:sopac_cache_object).returns(@store)
  end

  test 'does not call broker when registry already has devices' do
    cache = SopacBroker::Cache.new(@customer.id, store: @store)
    cache.write_measurement('238B019C', { 'id' => '238B019C', 'label' => 'Logger 1', 'm' => [] })

    SopacBroker::BrokerConnection.expects(:connect).never
    SopacBroker::RegistryBootstrap.call(@customer)
  end

  test 'samples measurements queue and registers devices without removing messages' do
    connection = mock('connection')
    channel = mock('channel')
    queue = mock('queue')
    delivery_info = mock('delivery_info')
    body = { id: '238B019C', label: 'Logger 1', m: [] }.to_json

    SopacBroker::BrokerConnection.expects(:connect).returns(connection)
    connection.expects(:create_channel).returns(channel)
    connection.expects(:open?).returns(true)
    connection.expects(:close)
    channel.expects(:queue).with('/SOPAC/CARTOWAY/measurements', passive: true).returns(queue)
    channel.expects(:close)
    queue.expects(:pop).with(manual_ack: true).returns([delivery_info, nil, body]).then.returns([nil, nil, nil])
    delivery_info.expects(:delivery_tag).returns(1)
    channel.expects(:nack).with(1, false, true)

    registry = SopacBroker::RegistryBootstrap.call(@customer)
    assert_equal 'Logger 1', registry['238B019C']['label']
  end
end
