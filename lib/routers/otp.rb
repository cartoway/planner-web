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
require 'rest_client'
#RestClient.log = $stdout


module Routers
  class Otp

    attr_accessor :cache_request, :cache_result

    def initialize(cache_request, cache_result)
      @cache_request, @cache_result = cache_request, cache_result
    end

    def compute(otp_url, router_id, from_lat, from_lng, to_lat, to_lng, datetime)
      key = [otp_url, router_id, from_lat, from_lng, to_lat, to_lng, datetime]

      result = @cache_result.read(key)
      if !result
        request = @cache_request.read(key)
        if !request
          request = RestClient.get(otp_url + '/otp/routers/' + router_id + '/plan', accept: :json, params: {
            fromPlace: [from_lat, from_lng].join(','),
            toPlace: [to_lat, to_lng].join(','),
            # Warning, full english fashion date and time
            time: datetime.strftime('%I:%M%p'),
            date: datetime.strftime('%m-%d-%Y'),
            maxWalkDistance: 500,
            arriveBy: false,
            wheelchair: false,
            showIntermediateStops: false
          })
          @cache_request.write(key, request && request.body)
        end

        data = JSON.parse(request)
        if !data['error'] && data['plan'] && data['plan']['itineraries']
          i = data['plan']['itineraries'][0]
          time = i['duration']
          distance = i['walkDistance'] || 0 # FIXME walk only
          points = i['legs'].collect{ |leg| leg['legGeometry']['points'] }.flat_map{ |code|
            FastPolylines.decode(code, 6)
          }
          trace = FastPolylines.encode(points, 6)
        else
          distance = nil
          time = nil
          trace = nil
        end

        result = [distance, time, trace]
        @cache_result.write(key, result)
      end

      result
    end

    def isochrone(otp_url, router_id, lat, lng, size, datetime)
      key = [otp_url, router_id, lat, lng, nil, nil, size, datetime]

      request = @cache_request.read(key)
      if !request
        params = {
          requestTimespanHours: 2,
          radiusMeters: 500,
          nContours: 1,
          contourSpacingMinutes: size / 60,
          crs: 'EPSG:2154', # FIXME France only
          fromPlace: [lat, lng].join(','),
          maxTransfers: 2,
          batch: true,
          # Warning, full english fashion date and time
          time: datetime.strftime('%I:%M%p'),
          date: datetime.strftime('%m-%d-%Y'),
          arriveBy: false,
          wheelchair: false,
          showIntermediateStops: false
        }
        resource = RestClient::Resource.new(otp_url + '/otp/routers/' + router_id + '/simpleIsochrone', timeout: nil)
        request = resource.get(params: params) { |response, request, result, &block|
          case response.code
          when 200
            response
          when 500
          else
            response.return!(request, result, &block)
          end
        }

        @cache_request.write(key, request && request.body)
      end

      if request
        data = JSON.parse(request)
        if data['features']
          # MultiPolygon was not supported by Leaflet.Draw
          # TODO: As geoman is now used, see if we can support it and extend the features
          data['features'].collect! { |feat|
            if feat['geometry']['type'] == 'LineString'
              feat['geometry']['type'] = 'Polygon'
              feat['geometry']['coordinates'] = [feat['geometry']['coordinates']]
            end
            feat
          }
          data.to_json
        else
          raise 'No polygon for this zone'
        end
      end
    end
  end
end
