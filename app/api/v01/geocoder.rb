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
class V01::Geocoder < Grape::API
  # Allow the class to use text/plain render while we use a default_format :json trough the API
  content_type :txt, "text/plain"

  helpers do
    # Never trust parameters from the scary internet, only allow the white list through.
    def destination_params
      p = ActionController::Parameters.new(params)
      p = p[:destination] if p.key?(:destination)
      p.permit(:q, :json_callback)
    end
  end

  resource :geocoder do
    desc 'Geocode.',
      detail: 'Return a list of address which match with input query.',
      nickname: 'geocode',
      is_array: true,
      success: V01::Status.success(:code_200),
      failure: V01::Status.failures(is_array: true)
    params do
      requires :q, type: String, desc: 'Free query string.'
      optional :lat, type: Float, desc: 'Prioritize results around this latitude.'
      optional :lng, type: Float, desc: 'Prioritize results around this longitude.'
      optional :limit, type: Integer, desc: 'Max results numbers. (default and upper max 10)'
    end
    get 'search' do
      json = Planner::Application.config.geocoder.code_free(params[:q], current_customer.default_country, params[:limit] || 10, params[:lat], params[:lng]).collect{ |result|
        {
          address: {
            housenumber: result[:housenumber],
            street: result[:street],
            postcode: result[:postcode],
            city: result[:city],
            country: result[:country]
          },
          boundingbox: [
            result[:lat],
            result[:lat],
            result[:lng],
            result[:lng]
          ],
          display_name: result[:free],
          importance: result[:accuracy],
          lat: result[:lat],
          lon: result[:lng],
        }
      }

      if params[:json_callback]
        content_type 'text/plain'
        "#{params[:json_callback]}(#{json.to_json})"
      else
        json
      end
    end
  end
end
