# frozen_string_literal: true

# Copyright © Cartoway, 2026
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
module Preferences
  module Catalog
    # User-level stop list primary line (planning sidebar): ordered fields, max 3 visible in "active".
    module StopList
      # Visit stops expose destination_* / visit_* via route/stop JSON; non-visit rows omit most of these.
      FIELD_IDS = %w[
        name ref destination_name destination_ref visit_ref
        street postalcode city country lat lng
        detail comment phone_number destination_duration tags tags_visit
        eta status
      ].freeze

      DEFAULT_ACTIVE = %w[name ref].freeze
      MAX_ACTIVE = 3

      module_function

      def default_zone
        {
          'active' => DEFAULT_ACTIVE.dup,
          'hidden' => (FIELD_IDS - DEFAULT_ACTIVE).dup
        }
      end

      def normalize_zone(raw)
        z = raw.is_a?(Hash) ? raw.stringify_keys : {}
        %w[active hidden].each do |side|
          next unless z[side].is_a?(Array)

          # Users who had the short-lived list field id "tags_destination" map back to "tags"
          z[side] = z[side].map { |id| id.to_s == 'tags_destination' ? 'tags' : id }.uniq
        end
        active = Core.filter_order(z['active'], FIELD_IDS)
        hidden_src = Core.filter_order(z['hidden'], FIELD_IDS)
        active.uniq!
        hidden_src.uniq!
        hidden_src -= active
        active = active.take(MAX_ACTIVE)
        if active.empty?
          active = Core.filter_order(DEFAULT_ACTIVE.dup, FIELD_IDS)
        end
        missing_hidden = FIELD_IDS.reject { |id| active.include?(id) }
        hidden_ordered = (hidden_src & missing_hidden) + (missing_hidden - hidden_src).sort_by { |id| FIELD_IDS.index(id) }
        { 'active' => active, 'hidden' => hidden_ordered }
      end

      def field_value(stop, field_id)
        return nil if stop.blank?

        fid = field_id.to_s
        return nil unless FIELD_IDS.include?(fid)

        case fid
        when 'name' then stop_get(stop, :name).presence
        when 'ref' then stop_get(stop, :ref).presence
        when 'destination_name'
          stop_get(stop, :destination_name).presence || (visit_stop?(stop) ? stop_get(stop, :name).presence : nil)
        when 'destination_ref'
          stop_get(stop, :destination_ref).presence || (visit_stop?(stop) ? stop_get(stop, :ref).presence : nil)
        when 'visit_ref' then stop_get(stop, :visit_ref).presence
        when 'street' then stop_get(stop, :street).presence&.to_s
        when 'postalcode' then stop_get(stop, :postalcode).presence&.to_s
        when 'city' then stop_get(stop, :city).presence&.to_s
        when 'country' then stop_get(stop, :country).presence&.to_s
        when 'lat' then coord_display(stop_get(stop, :lat))
        when 'lng' then coord_display(stop_get(stop, :lng))
        when 'detail' then stop_get(stop, :detail).presence&.to_s
        when 'comment' then stop_get(stop, :comment).presence&.to_s
        when 'phone_number' then stop_get(stop, :phone_number).presence&.to_s
        when 'destination_duration' then stop_get(stop, :destination_duration).presence&.to_s
        when 'tags' then tags_labels_from_key(stop_get(stop, :tags_present), 'tags')
        when 'tags_visit' then tags_labels_from_key(stop_get(stop, :tags_present), 'tags_visit')
        when 'eta' then stop_get(stop, :eta_formated).presence
        when 'status' then stop_get(stop, :status).presence
        end
      end

      def stop_get(stop, key)
        return nil unless stop.respond_to?(:[])

        stop[key.to_s] || stop[key] || stop[key.to_sym]
      end
      private_class_method :stop_get

      def visit_stop?(stop)
        ActiveModel::Type::Boolean.new.cast(stop_get(stop, :visits))
      end
      private_class_method :visit_stop?

      def tags_labels_from_key(tag_data, key)
        return nil unless tag_data.is_a?(Hash)

        raw = tag_data[key.to_s] || tag_data[key.to_sym]
        normalize_tag_labels_line(raw)
      end
      private_class_method :tags_labels_from_key

      def normalize_tag_labels_line(raw)
        return nil if raw.blank?

        labels = Array(raw).map do |t|
          t.is_a?(Hash) ? (t['label'] || t[:label]) : t
        end
        labels.compact.map(&:to_s).reject(&:blank?).join(', ').presence
      end
      private_class_method :normalize_tag_labels_line

      def coord_display(val)
        return nil if val.nil? || val == ''

        f = Float(val)
        s = format('%.6f', f)
        s.sub(/\.?0+\z/, '')
      rescue ArgumentError, TypeError
        nil
      end
      private_class_method :coord_display
    end
  end
end
