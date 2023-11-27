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
module SharedParams
  extend Grape::API::Helpers

  params :request_destination do
    optional :ref, type: String
    optional :name, type: String
    optional :street, type: String
    optional :postalcode, type: String
    optional :city, type: String
    optional :state, type: String
    optional :country, type: String
    optional :lat, type: Float
    optional :lng, type: Float
    optional :detail, type: String
    optional :comment, type: String
    optional :phone_number, type: String
    optional :geocoding_accuracy, type: Float
    optional :geocoding_level, type: String, values: ['point', 'house', 'street', 'intersection', 'city']
    optional :tag_ids, type: Array[Integer], desc: 'Ids separated by comma.', coerce_with: CoerceArrayInteger, documentation: { param_type: 'form' }
    optional :geocoded_at,  type: Time, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(val) { val.is_a?(String) ? Time.parse(val + ' UTC') : val }
    optional :geocoder_version, type: String
    optional :visits, type: Array do
      optional :id, type: Integer, documentation: { desc: 'Required to retrieve an exising visit, if left blank a new visit will be created' }
      :request_visit
    end
    optional :geocoding_accuracy, type: Float, documentation: { desc: 'Must be inside 0..1 range.' }
  end

  params :request_visit do
    optional :tag_ids, type: Array[Integer], desc: 'Ids separated by comma.', coerce_with: CoerceArrayInteger, documentation: { param_type: 'form' }

    optional :quantities, type: Array do
      optional :deliverable_unit_id, type: Integer
      optional :quantity, type: Float
      all_or_none_of :deliverable_unit_id, :quantity
    end

    optional :time_window_start_1, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
    optional :open1, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
    mutually_exclusive :time_window_start_1, :open1

    optional :time_window_end_1, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
    optional :close1, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
    mutually_exclusive :time_window_end_1, :close1

    optional :duration, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
    optional :time_window_start_2, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
    optional :open2, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
    mutually_exclusive :time_window_start_2, :open2

    optional :time_window_end_2, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
    optional :close2, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.type_cast(value) }
    mutually_exclusive :time_window_end_2, :close2
  end

  params :params_from_entity do |options|
    options[:entity].each{ |k, d|
      v = d.dup # Important: use dup not to modify original entity
      v[:type] = Boolean if v[:type] == 'Boolean'
      # To be homogeneous with rails and avoid timezone problems, need to use Time instead of DateTime
      if v[:type] == DateTime
        v[:type] = Time
        v[:coerce_with] = ->(val) { val.is_a?(String) ? Time.parse(val + ' UTC') : val }
      end
      if v[:values]
        classes = v[:values].map(&:class).uniq
        v[:type] = classes[0] if classes.size == 1 && v[:type] != classes[0]
      end
      v[:type] = Array[v[:type]] if v.key?(:is_array)
      send(v[:required] ? :requires : :optional, k, v.except(:required, :is_array, :param_type))
    }
  end

  ID_DESC = 'Id or the ref field value, then use "ref:[value]".'.freeze
  DATE_DESC = "Local format depends of the locale sent in http header. Default local send is english (:en)\n
  ex:\n
  en: mm-dd-yyyy\n
  fr: dd-mm-yyyy"
  MAX_DAYS = 31
end
