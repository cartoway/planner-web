# Copyright © Mapotempo, 2013-2014
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
module ZoningsHelper
  def zoning_vehicles(zoning, planning = nil, options = {})
    if planning && planning.vehicle_usage_set.present?
      planning.vehicle_usage_set.vehicle_usages.select{ |v|
        options[:active].nil? || options[:active] == v.active
      }.map(&:vehicle)
    else
      VehicleUsage.where(vehicle_usage_set_id: zoning.customer.vehicle_usage_set_ids).select{ |v|
        options[:active].nil? || options[:active] == v.active
      }.map(&:vehicle).uniq
    end
  end

  def zoning_details(zoning)
    zoning.zones.each_with_object({}) do |zone, hash|
      hash[zone.id] = zone.attributes.slice('vehicle_id').merge('avoid_zone' => zone.avoid_zone)
    end
  end

  def zoning_select(f, planning, options = {})
    input_group = content_tag('a', content_tag('i', nil, class: 'fa fa-plus fa-fw'), href: url_for([:new, :zonings, planning, back: true]), class: 'btn btn-default', title: t('plannings.edit.zoning_new')) if !planning.new_record?
    f.select :zoning_ids, options_for_select(planning.customer.zonings.map{ |zoning| [zoning.name, zoning.id] }, planning.zonings.map(&:id)), { control_col: 'col-xs-12 col-md-12', label_class: (options[:label] ? '' : 'd-none') }.merge(options), { multiple: true, input_group: input_group }
  end
end
