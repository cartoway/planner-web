# Copyright © Mapotempo, 2014-2015
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
require 'grape-swagger'
require 'grape_logging'

class ApiRootDef < Grape::API
  include Grape::Extensions::Hash::ParamBuilder

  unless Rails.env.test?
    logger.formatter = ENV['LOG_FORMAT'] == 'json' ? GrapeLogging::Formatters::Json.new : GrapeLogging::Formatters::Default.new
    insert_before Grape::Middleware::Error, GrapeLogging::Middleware::RequestLogger, logger: logger, include: [
      GrapeLogging::Loggers::FilterParameters.new,
      GrapeLogging::Loggers::ClientEnv.new,
    ]
  end

  rescue_from(:all) { |error|
    logger.error(error)
    raise error
  }

  mount ApiV01
  mount ApiV100
end

ApiRoot = Rack::Builder.new do
  use ApiCors
  run ApiRootDef
end
