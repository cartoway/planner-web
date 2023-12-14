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
require 'json'
require 'fast_polylines'

#RestClient.log = $stdout

module Routers
  class Here

    attr_accessor :cache_request, :cache_result
    attr_accessor :url, :app_id, :app_code

    def initialize(cache_request, cache_result, url_router, url_matrix, url_isoline, app_id, app_code)
      @cache_request, @cache_result = cache_request, cache_result
      @url_router, @url_matrix, @url_isoline, @app_id, @app_code = url_router, url_matrix, url_isoline, app_id, app_code
    end

    def compute(from_lat, from_lng, to_lat, to_lng)
      key = [from_lat, from_lng, to_lat, to_lng]

      result = @cache_result.read(key)
      if !result
        request = get(@url_router, '7.2/calculateroute',
          waypoint0: "geo!#{from_lat},#{from_lng}",
          waypoint1: "geo!#{to_lat},#{to_lng}",
          mode: 'fastest;truck;traffic:disabled',
          alternatives: 0,
          resolution: 1,
          representation: 'display',
          routeAttributes: 'summary,shape',
          truckType: 'truck',
          #limitedWeight: # Truck routing only, vehicle weight including trailers and shipped goods, in tons.
          #weightPerAxle: # Truck routing only, vehicle weight per axle in tons.
          #height: # Truck routing only, vehicle height in meters.
          #width: # Truck routing only, vehicle width in meters.
          #length: # Truck routing only, vehicle length in meters.
          #tunnelCategory : # Specifies the tunnel category to restrict certain route links. The route will pass only through tunnels of a less strict category. Enum [B | C | D | E]
        )

        if request && request['response'] && request['response']['route']
          r = request['response']['route'][0]
          s = r['summary']
          result = [s['distance'], s['trafficTime'], FastPolylines.encode(r['shape'].collect{ |p|
            p.split(',').collect{ |f| Float(f) }
          }, 6)]
        else
          result = [nil, nil, nil]
        end
        @cache_result.write(key, result)
      end

      result
    end

    def matrix(row, column, mode, &block)
      raise 'More than 100x100 matrix, not possible with Here' if row.size > 100 || column.size > 100

      # do not modify row/column inputs if an index is used by pack_vector/unpack_vector
      row = row.collect{ |r| [r[0].round(5), r[1].round(5)] }
      column = column.collect{ |c| [c[0].round(5), c[1].round(5)] }

      key = Digest::MD5.hexdigest(Marshal.dump([row, column, mode]))

      result = @cache_result.read(key)
      if !result

        # From Here "Matrix Routing API Developer's Guide"
        # Recommendations for Splitting Matrixes
        # The best way to split a matrix request is to split it into parts with only few start positions and many
        # destinations. The number of the start positions should be between 3 and 15, depending on the size
        # of the area covered by the matrix. The matrices should be split into requests sufficiently small to
        # ensure a response time of 30 seconds each. The number of the destinations in one request is limited
        # to 100.

        # Request should not contain more than 15 starts per request
        # 500 to get response before 30 seconds timeout
        split_size = [5, (1000 / row.size).round].min

        result = Array.new(row.size) { Array.new(column.size) }

        commons_param = {
          mode: 'fastest;truck;traffic:disabled',
          truckType: 'truck',
          summaryAttributes: (mode == :distance) ? mode.to_s : 'traveltime',
          #limitedWeight: # Truck routing only, vehicle weight including trailers and shipped goods, in tons.
          #weightPerAxle: # Truck routing only, vehicle weight per axle in tons.
          #height: # Truck routing only, vehicle height in meters.
          #width: # Truck routing only, vehicle width in meters.
          #length: # Truck routing only, vehicle length in meters.
        }
        0.upto(column.size - 1).each{ |i|
          commons_param["destination#{i}"] = column[i].join(',')
        }

        total = row.size * column.size
        row_start = 0
        while row_start < row.size do
          request = @cache_result.read([key, row_start, split_size])
          if !request
            param = commons_param.dup
            row_start.upto([row_start + split_size - 1, row.size - 1].min).each{ |i|
              param["start#{i - row_start}"] = row[i].join(',')
            }
            request = get(@url_matrix, '7.2/calculatematrix', param)
            @cache_result.write([key, row_start, split_size], request)
          end

          request['response']['matrixEntry'].each{ |e|
            travel_time = e['summary'] ? e['summary']['travelTime'].round : 2147483647
            result[row_start + e['startIndex']][e['destinationIndex']] = [travel_time, travel_time]
          }

          row_start += split_size
          block.call(column.size * split_size, total) if block
        end

        @cache_result.write(key, result)
      end

      result
    end

    private

    def get(base_url, object, params = {})
      url = "#{base_url}/#{object}.json"
      params = {app_id: @app_id, app_code: @app_code}.merge(params)

      key = [url, params].hash
      request = @cache_request.read(key)
      if !request
        begin
          response = RestClient.get(url, params: params)
        rescue RestClient::Exception => e
          error = JSON.parse(e.response)
          if error['type'] == 'ApplicationError'
            additional_data = error['AdditionalData'] || error['additionalData']
            if additional_data
              if additional_data.include?('key' => 'error_code', 'value' => 'NGEO_ERROR_GRAPH_DISCONNECTED')
                return
              elsif additional_data.include?('key' => 'error_code', 'value' => 'NGEO_ERROR_ROUTE_NO_START_POINT')
                raise UnreachablePointError
              else
                raise
              end
            end
          end
          Rails.logger.info [url, params]
          Rails.logger.info error
          raise ['Here', error['type']].join(' ')
        end
        request = JSON.parse(response)
        @cache_request.write(key, request)
      end

      request
    end
  end
end
