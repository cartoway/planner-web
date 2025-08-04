# Copyright © Mapotempo, 2013-2015
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
require 'rest_client'
#RestClient.log = $stdout

class RouterError < StandardError; end

module Routers
  class Osrm

    attr_accessor :cache_request, :cache_result

    def initialize(cache_request, cache_result)
      @cache_request, @cache_result = cache_request, cache_result
    end

    def compute(osrm_url, from_lat, from_lng, to_lat, to_lng)
      key = [osrm_url, from_lat, from_lng, to_lat, to_lng]

      result = @cache_result.read(key)
      if !result
        request = @cache_request.read(key)
        if !request
          begin
            uri = URI(url = "#{osrm_url}/viaroute")
            uri.query = "loc=#{from_lat},#{from_lng}&loc=#{to_lat},#{to_lng}&alt=false&output=json"
            Rails.logger.info "get #{uri}"
            res = Net::HTTP.get_response(uri)
            if res.nil?
              raise 'No connection to the host'
            elsif res.is_a?(Net::HTTPSuccess)
              request = JSON.parse(res.body)
              @cache_request.write(key, request)
            else
              raise RouterError.new(res.message)
            end
          rescue OpenSSL::SSL::SSLError
            raise 'Unable to communicate over SSL'
          rescue Errno::ECONNREFUSED
            raise 'Connection was refused'
          rescue Errno::ETIMEDOUT
            raise 'Timed out connecting'
          rescue Errno::EHOSTDOWN
            raise 'The host not responding to requests'
          rescue Errno::EHOSTUNREACH
            raise 'Possible network issue communicating'
          rescue SocketError
            raise "Couldn't make sense of the host destination"
          rescue JSON::ParserError
            raise 'The host returned a non-JSON response'
          end
        end

        if request['route_summary']
          distance = request['route_summary']['total_distance']
          time = request['route_summary']['total_time']
          trace = request['route_geometry']
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

    def matrix(osrm_url, vector)
      key = [osrm_url, vector.map{ |v| v[0..1] }.hash]

      result = @cache_result.read(key)
      if !result
        request = @cache_request.read(key)
        if !request
          begin
            uri = URI(url = "#{osrm_url}/table")
            uri.query = vector.map{ |a| "loc=#{a[0]},#{a[1]}" }.join('&')
            Rails.logger.info "get #{uri}"
            res = Net::HTTP.get_response(uri)
            if res.nil?
              raise 'No connection to the host'
            elsif res.is_a?(Net::HTTPSuccess)
              request = JSON.parse(res.body)
              @cache_request.write(key, request)
            else
              raise res.message
            end
          rescue OpenSSL::SSL::SSLError
            raise 'Unable to communicate over SSL'
          rescue Errno::ECONNREFUSED
            raise 'Connection was refused'
          rescue Errno::ETIMEDOUT
            raise 'Timed out connecting'
          rescue Errno::EHOSTDOWN
            raise 'The host not responding to requests'
          rescue Errno::EHOSTUNREACH
            raise 'Possible network issue communicating'
          rescue SocketError
            raise "Couldn't make sense of the host destination"
          rescue JSON::ParserError
            raise 'The host returned a non-JSON response'
          end
        end

        result = request['distance_table'].collect{ |r|
          r.collect{ |rr|
            (rr / 10).round # TODO >= 2147483647 ? nil : (rr / 10).round
          }
        }
        @cache_result.write(key, result)
      end

      result
    end

    def isochrone(osrm_isochrone_url, lat, lng, size)
      key = [osrm_isochrone_url, lat, lng, size]

      request = @cache_request.read(key)
      if !request
        params = {
          lat: lat,
          lng: lng,
          time: size
        }
        resource = RestClient::Resource.new(osrm_isochrone_url + '/0.1/isochrone', timeout: nil)
        request = resource.get(params: params) { |response, request, result, &block|
          case response.code
          when 200
            response
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
