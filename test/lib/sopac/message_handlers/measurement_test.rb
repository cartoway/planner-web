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

class SopacBroker::MessageHandlers::MeasurementTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
    @store = ActiveSupport::Cache::MemoryStore.new
    @cache = SopacBroker::Cache.new(@customer.id, store: @store)
    SopacBroker::Cache.stubs(:new).returns(@cache)
  end

  test 'stores measurement and registers device from JSON payload' do
    body = {
      id: '238B019C',
      label: 'Logger 1',
      m: [{ t: 28.3, h: 63.7, utc: 1_501_688_218_000, hub: '000001e0' }]
    }.to_json

    SopacBroker::MessageHandlers::Measurement.call(@customer.id, body)

    stored = @cache.read_measurement('238B019C')
    assert_equal '238B019C', stored['id']
    assert_equal '000001e0', @cache.read_logger_hub('238B019C')
    assert_equal 'Logger 1', @cache.devices_registry['238B019C']['label']
  end
end
