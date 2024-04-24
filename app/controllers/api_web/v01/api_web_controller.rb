# Copyright © Mapotempo, 2015
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
require 'parse_ids_refs'

class ApiWeb::V01::ApiWebController < ApplicationController
  before_action :skip_trackable
  after_action :allow_iframe
  layout 'api_web/v01'

  private

  def skip_trackable
   request.env['devise.skip_trackable'] = true
  end

  def allow_iframe
    response.headers.delete 'X-Frame-Options'
  end
end
