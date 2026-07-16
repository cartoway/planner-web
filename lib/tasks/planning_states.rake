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

namespace :planning_states do
  desc 'Delete planning states older than the retention period (default 12 weeks, override with RETENTION_WEEKS)'
  task purge: :environment do
    retention_weeks = ENV.fetch('RETENTION_WEEKS', PlanningState::RETENTION_WEEKS).to_i
    deleted = PlanningState.purge_stale!(retention_weeks: retention_weeks)
    puts "Purged planning states captured before #{retention_weeks} weeks ago (#{deleted} rows deleted)"
  end
end
