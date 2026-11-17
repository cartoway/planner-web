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

class RackAttackConfigTest < ActiveSupport::TestCase
  test 'loads throttle limits from config/rack_attack.yml' do
    cfg = RackAttackConfig.load
    assert_equal({ limit: 300, period: 60 }, RackAttackConfig.limits_for(cfg, 'driver_token'))
    assert_equal({ limit: 10, period: 3600 }, RackAttackConfig.limits_for(cfg, 'driver_session_email'))
  end
end
