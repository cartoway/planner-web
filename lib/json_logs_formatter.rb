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

class StructuredLog < ActiveSupport::Logger
  def merge(message, **args)
    if ENV['LOG_FORMAT'] == 'json'
      if message[0] == '{' && message[-1] == '}' && args.empty?
        message
      elsif message[0] == '{' && message[-1] == '}'
        JSON.parse(message).merge(args).to_json
      else
        args[:message] = message
        args.to_json
      end
    else
      [message.to_s, args&.to_json].compact.join(' ')
    end
  end

  def debug(message, **args)
    super(merge(message, **args))
  end

  def info(message, **args)
    super(merge(message, **args))
  end

  def warn(message, **args)
    super(merge(message, **args))
  end

  def fatal(message, **args)
    super(merge(message, **args))
  end

  def unknown(message, **args)
    super(merge(message, **args))
  end
end

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
