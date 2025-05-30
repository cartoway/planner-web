# Copyright © Mapotempo, 2016
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
require './lib/simplify_geometry'
#RestClient.log = $stdout

class RouterError < StandardError; end

module Routers
  class RouterWrapper

    attr_accessor :cache_request, :cache_result, :url, :api_key

    def initialize(cache_request, cache_result, api_key)
      @cache_request, @cache_result = cache_request, cache_result
      @api_key = api_key
    end

    def compute_batch(url, mode, dimension, segments, options = {})
      results = {}
      nocache_segments = []
      sorted_options = options.to_a.sort_by{ |i| i[0].to_s }

      segments.each{ |s|
        key_segment = ['c', url, mode, dimension, Digest::MD5.hexdigest(Marshal.dump([s, sorted_options]))]
        request_segment = @cache_request.read key_segment
        if request_segment
          results[s] = JSON.parse request_segment
        else
          nocache_segments << s if !request_segment
        end
      }

      process_nocache_segments(nocache_segments, url, mode, dimension, options, sorted_options, results) unless nocache_segments.empty?

      return [] if results.empty?

      segments.map do |segment|
        next [nil, nil, nil] unless (feature = results[segment])

        extract_feature_data(feature)
      end
    end

    def matrix(url, mode, dimensions, row, column, options = {})
      if row.empty? || column.empty?
        return [[] * row.size] * column.size
      elsif row.size == 1 && row == column
        return dimensions.map{ |d| [[0]] }
      end

      key = ['m', url, mode, dimensions, Digest::MD5.hexdigest(Marshal.dump([row, column, options.to_a.sort_by{ |i| i[0].to_s }]))]

      request = @cache_request.read(key)
      if !request
        resource = RestClient::Resource.new(url + '/matrix.json', timeout: nil)
        request = resource.post(params(mode, dimensions.join('_'), options).merge({
          src: row.flatten.join(','),
          dst: row != column ? column.flatten.join(',') : nil,
        }.compact)) { |response, request, result, &block|
          case response.code
          when 200
            response
          when 417
            ''
          else
            response = (response && /json/.match(response.headers[:content_type]) && response.size > 1) ? JSON.parse(response) : nil
            raise RouterError.new(result.message + (response && response['message'] ? ' - ' + response['message'] : ''))
          end
        }

        @cache_request.write(key, request && request.to_s)
      end

      unless request.to_s.empty?
        data = JSON.parse(request)
        dimensions.collect{ |dim|
          if data.key?("matrix_#{dim}")
            data["matrix_#{dim}"].collect{ |r|
              r.collect{ |rr|
                rr || 2147483647
              }
            }
          end
        }
      end
    end

    def isoline(url, mode, dimension, lat, lng, size, options = {})
      key = ['i', url, mode, dimension, Digest::MD5.hexdigest(Marshal.dump([lat, lng, size, options.to_a.sort_by{ |i| i[0].to_s }]))]

      request = @cache_request.read(key)
      if !request
        resource = RestClient::Resource.new(url + '/isoline.json', timeout: nil)
        request = resource.post(params(mode, dimension, options).merge({
          loc: [lat, lng].join(','),
          size: size,
        })) { |response, request, result, &block|
          case response.code
          when 200
            response
          when 417
            ''
          else
            response = (response && /json/.match(response.headers[:content_type]) && response.size > 1) ? JSON.parse(response) : nil
            raise RouterError.new(result.message + (response && response['message'] ? ' - ' + response['message'] : ''))
          end
        }

        @cache_request.write(key, request && request.to_s)
      end

      if request != ''
        data = JSON.parse(request)
        if data['features']
          # MultiPolygon not supported by Leaflet.Draw
          data['features'].collect! { |feat|
            if feat['geometry']['type'] == 'LineString'
              feat['geometry']['type'] = 'Polygon'
              feat['geometry']['coordinates'] = [feat['geometry']['coordinates']]
            end
            feat
          }
          data.to_json
        end
      end
    end

    private

    def params(mode, dimension, options)
      {
        api_key: @api_key,
        mode: mode,
        dimension: dimension,
        geometry: options[:geometry],
        traffic: options[:traffic],
        departure: options[:departure],
        speed_multiplier: options[:speed_multiplier] == 1 ? nil : options[:speed_multiplier],
        area: options[:speed_multiplier_areas] ? options[:speed_multiplier_areas].collect{ |a| a[:area].join(',') }.join('|') : nil,
        speed_multiplier_area: options[:speed_multiplier_areas] ? options[:speed_multiplier_areas].collect{ |a| a[:speed_multiplier_area] }.join('|') : nil,
        track: options[:track],
        low_emission_zone: options[:low_emission_zone],
        motorway: options[:motorway],
        toll: options[:toll],
        trailers: options[:trailers],
        weight: options[:weight],
        weight_per_axle: options[:weight_per_axle],
        height: options[:height],
        width: options[:width],
        length: options[:length],
        hazardous_goods: options[:hazardous_goods],
        max_walk_distance: options[:max_walk_distance],
        approach: options[:approach],
        snap: options[:snap],
        strict_restriction: options[:strict_restriction] || false
      }.compact
    end

    def cache_key(url, mode, dimension, segment, sorted_options)
      ['c', url, mode, dimension, Digest::MD5.hexdigest(Marshal.dump([segment, sorted_options]))]
    end

    def process_nocache_segments(nocache_segments, url, mode, dimension, options, sorted_options, results)
      nocache_segments.each_slice(50) do |slice_segments|
        response = fetch_route_data(url, mode, dimension, options, slice_segments)
        next if response.empty?

        process_response(response, slice_segments, url, mode, dimension, sorted_options, results)
      end
    end

    def fetch_route_data(url, mode, dimension, options, segments)
      resource = RestClient::Resource.new(url + '/routes.json', timeout: nil)

      resource.post(build_params(mode, dimension, options, segments)) do |response, request, result|
        handle_response(response, result)
      end
    end

    def build_params(mode, dimension, options, segments)
      params(mode, dimension, options).merge({
        locs: segments.map{ |segment| segment.join(',') }.join('|'),
        precision: 6
      })
    end

    def handle_response(response, result)
      case response.code
      when 200 then response
      when 204 then '' # UnreachablePointError
      when 417 then '' # OutOfSupportedAreaError
      else
        response_data = parse_error_response(response)
        raise RouterError.new(result.message + response_data)
      end
    end

    def parse_error_response(response)
      return '' unless response && /json/.match(response.headers[:content_type]) && response.size > 1

      data = JSON.parse(response)
      data['message'] ? " - #{data['message']}" : ''
    rescue JSON::ParserError
      ''
    end

    def process_response(response, segments, url, mode, dimension, sorted_options, results)
      return unless response.present?

      data = JSON.parse(response)
      return unless data && data['features']&.any?

      segments.each_with_index do |segment, index|
        next unless (feature = data['features'][index])

        key = cache_key(url, mode, dimension, segment, sorted_options)
        @cache_request.write(key, feature.to_json)
        results[segment] = feature
      end
    end

    def extract_feature_data(feature)
      properties = feature['properties']&.dig('router')
      geometry = feature['geometry']

      [
        properties&.dig('total_distance'),
        properties&.dig('total_time'),
        geometry&.dig('polylines')
      ]
    end
  end
end
