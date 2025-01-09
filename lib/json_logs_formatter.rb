# Copyright © Cartoway, 2025
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

class JsonLogsFormatter < ActiveSupport::Logger::SimpleFormatter
  MAGIC = 'ncdjjfaherifjrefjl'.freeze

  def call(severity, timestamp, _progname, message)
    json =
      if message[0] == '{' && message[-1] == '}'
        {
          type: severity,
          message: MAGIC
        }.to_json.gsub("\"#{MAGIC}\"", message)
      else
        {
          type: severity,
          message: message
        }.to_json
      end

    "#{json}\n"
  rescue StandardError
    json = {
      type: severity,
      message: message,
    }.to_json
    "#{json}\n"
  end
end
