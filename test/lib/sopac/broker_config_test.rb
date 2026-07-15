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

class SopacBroker::BrokerConfigTest < ActiveSupport::TestCase
  test 'normalize_queue_prefix adds leading slash' do
    assert_equal '/SOPAC/CARTOWAY', SopacBroker::BrokerConfig.normalize_queue_prefix('SOPAC/CARTOWAY')
    assert_equal '/SOPAC/CARTOWAY', SopacBroker::BrokerConfig.normalize_queue_prefix('/SOPAC/CARTOWAY')
  end

  test 'normalize_queue_prefix prepends org segment for account slug only' do
    assert_equal '/SOPAC/CARTOWAY', SopacBroker::BrokerConfig.normalize_queue_prefix('CARTOWAY')
  end

  test 'from_credentials builds queue names from request params' do
    config = SopacBroker::BrokerConfig.from_credentials(
      username: 'user',
      password: 'pass',
      queue_prefix: 'SOPAC/CARTOWAY'
    )
    assert SopacBroker::BrokerConfig.valid?(config)
    assert_equal '/SOPAC/CARTOWAY/measurements', config[:queue_names][:measurements]
  end

  test 'customer_enabled? is false when sopac is disabled on customer' do
    customer = customers(:customer_one)
    customer.update!(devices: { sopac: { enable: 'false', username: 'u', password: 'p', queue_prefix: '/SOPAC/X' } })

    assert_not SopacBroker::BrokerConfig.customer_enabled?(customer)
  end

  test 'valid? requires username password and queue names' do
    config = SopacBroker::BrokerConfig.from_credentials(username: 'u', password: 'p', queue_prefix: '/SOPAC/X')

    assert SopacBroker::BrokerConfig.valid?(config)
    assert_not SopacBroker::BrokerConfig.valid?(config.merge(password: nil))
  end
end
