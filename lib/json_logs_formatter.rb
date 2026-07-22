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
    if ENV.fetch('LOG_FORMAT', nil) == 'json'
      text = message.is_a?(String) ? message : message.to_s
      if text.start_with?('{') && text.end_with?('}') && args.empty?
        text
      elsif text.start_with?('{') && text.end_with?('}')
        JSON.parse(text).merge(args).to_json
      else
        args.merge(message: text).to_json
      end
    else
      [message.to_s, args&.to_json].compact.join(' ')
    end
  end

  def debug(message = '', **args)
    super(merge(message, **args))
  end

  def info(message = '', **args)
    super(merge(message, **args))
  end

  def warn(message = '', **args)
    super(merge(message, **args))
  end

  def fatal(message = '', **args)
    super(merge(message, **args))
  end

  def unknown(message = '', **args)
    super(merge(message, **args))
  end
end

class JsonLogsFormatter < ActiveSupport::Logger::SimpleFormatter
  MAGIC = 'ncdjjfaherifjrefjl'.freeze

  def call(severity, timestamp, _progname, message)
    text = message.is_a?(String) ? message : message.to_s
    json =
      if text.start_with?('{') && text.end_with?('}')
        {
          type: severity,
          message: MAGIC
        }.to_json.gsub("\"#{MAGIC}\"", text)
      else
        {
          type: severity,
          message: text
        }.to_json
      end

    "#{json}\n"
  rescue StandardError
    json = {
      type: severity,
      message: message.to_s,
    }.to_json
    "#{json}\n"
  end
end
