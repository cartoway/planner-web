# Copyright © Mapotempo, 2017
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
require 'coerce'

# Specific file to get plannings because it needs to return specific content types (js, xml and geojson)
class V01::VisitsGet < Grape::API
  content_type :json, 'application/json; charset=UTF-8'
  content_type :geojson, 'application/vnd.geo+json; charset=UTF-8'
  content_type :xml, 'application/xml'
  default_format :json

  helpers SharedParams

  resource :visits do
    desc 'Fetch customer\'s visits.',
      nickname: 'getVisits',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::Visit),
      failure: V01::Status.failures(is_array: true)
    params do
      optional :ids, type: Array[String], desc: 'Select returned visits by id separated with comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
      optional :quantities, type: Boolean, default: false, desc: 'Include the quantities when using geojson output.'
    end
    get do
      visits =
        if params.key?(:ids)
          current_customer.visits.select{ |visit|
            params[:ids].any?{ |s| ParseIdsRefs.match(s, visit) }
          }
        else
          current_customer.visits
        end
      if env['api.format'] == :geojson
        '{"type":"FeatureCollection","features":[' + visits.map { |visit|
          if visit.destination.position?
            feat = {
              type: 'Feature',
              geometry: {
                type: 'Point',
                coordinates: [visit.lng.round(6), visit.lat.round(6)]
              },
              properties: {
                visit_id: visit.id,
                color: visit.default_color,
                icon: visit.icon,
                icon_size: visit.icon_size
              }
            }
            feat[:properties][:quantities] = []
            deliveries = visit.default_deliveries
            pickups = visit.default_pickups
            current_customer.deliverable_units.each { |du|
              next if pickups[du.id].blank? && deliveries[du.id].blank?

              feat[:properties][:quantities] << {
                deliverable_unit_id: du.id,
                pickup: pickups[du.id],
                delivery: deliveries[du.id]
              }.compact
            }
            feat.to_json
          end
        }.compact.join(',') + ']}'
      else
        present visits, with: V01::Entities::Visit
      end
    end
  end
end
