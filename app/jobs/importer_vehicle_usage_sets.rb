# Copyright © Mapotempo, 2013-2016
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
require 'case_insensitive_hash'
require 'geocoder_stores_job'
require 'importer_base'

class ImporterVehicleUsageSets < ImporterBase

  def max_lines
    # Limit to the number of max vehicles
    @customer.max_vehicles
  end

  def columns_vehicle
    router_modes = @customer.profile.routers.pluck(:mode)
    router_dimensions = ::Router::DIMENSION.keys
    router_options = @customer.profile.routers.pluck(:options).reduce(:merge).except('time', 'distance', 'isochrone', 'avoid_zones', 'isodistance').keys

    {
      ref_vehicle: { title: I18n.t('vehicles.import.ref_vehicle'), desc: I18n.t('vehicles.import.ref_desc'), format: I18n.t('vehicles.import.format.string') },
      name_vehicle: { title: I18n.t('vehicles.import.name_vehicle'), desc: I18n.t('vehicles.import.name_desc'), format: I18n.t('vehicles.import.format.string'), required: I18n.t('vehicle_usage_sets.import.format.required') },
      contact_email: { title: I18n.t('vehicles.import.contact_email'), desc: I18n.t('vehicles.import.contact_email_desc'), format: I18n.t('vehicles.import.format.string') },
      phone_number: { title: I18n.t('vehicles.import.phone_number'), desc: I18n.t('vehicles.import.phone_number_desc'), format: I18n.t('vehicles.import.format.string') },
      emission: { title: I18n.t('vehicles.import.emission'), desc: I18n.t('vehicles.import.emission_desc'), format: '[' + ::Vehicle.emissions_hash.values.map { |emission| emission[0] }.join(' | ') + ']' },
      consumption: { title: I18n.t('vehicles.import.consumption'), desc: I18n.t('vehicles.import.consumption_desc'), format: I18n.t('vehicles.import.format.float') },
      max_distance: { title: I18n.t('vehicles.import.max_distance'), desc: I18n.t('vehicles.import.max_distance_desc'), format: I18n.t('vehicles.import.format.integer') },
      max_ride_distance: { title: I18n.t('vehicles.import.max_ride_distance'), desc: I18n.t('vehicles.import.max_ride_distance_desc'), format: I18n.t('vehicles.import.format.integer') },
      max_ride_duration: { title: I18n.t('vehicles.import.max_ride_duration'), desc: I18n.t('vehicles.import.max_ride_duration_desc'), format: I18n.t('vehicles.import.format.integer') }
    }.merge(Hash[@customer.deliverable_units.map { |du|
      ["capacity#{du.id}".to_sym, { title: I18n.t('vehicles.import.capacities') + (du.label ? "[#{du.label}]" : "#{du.id}"), desc: I18n.t('vehicles.import.capacities_desc'), format: I18n.t('vehicles.import.format.float') }]
    }]).merge(
      router_mode: { title: I18n.t('vehicles.import.router_mode'), desc: I18n.t('vehicles.import.router_mode_desc'), format: "[#{router_modes.join(' | ')}]" },
      router_dimension: { title: I18n.t('vehicles.import.router_dimension'), desc: I18n.t('vehicles.import.router_dimension_desc'), format: "[#{router_dimensions.join(' | ')}]" },
      router_options: { title: I18n.t('vehicles.import.router_options'), desc: I18n.t('vehicles.import.router_options_desc'), format: I18n.t('vehicles.import.format.json') + " [#{router_options.join(' | ')}]" },
      speed_multiplier: { title: I18n.t('vehicles.import.speed_multiplier'), desc: I18n.t('vehicles.import.speed_multiplier_desc'), format: I18n.t('vehicles.import.format.integer') },
      color: { title: I18n.t('vehicles.import.color'), desc: I18n.t('vehicles.import.color_desc'), format: I18n.t('vehicles.import.format.string') },
      tags_vehicle: { title: I18n.t('vehicles.import.tags'), desc: I18n.t('vehicles.import.tags_desc'), format: I18n.t('vehicles.import.tags_format') },
      devices: { title: I18n.t('vehicles.import.devices'), desc: I18n.t('vehicles.import.devices_desc'), format: I18n.t('vehicles.import.format.string') }
    ).merge(Hash[@customer.custom_attributes.for_vehicle.map { |ca|
      ["custom_attributes[#{ca.name}]", { title: "#{I18n.t('vehicles.import.custom_attributes')}[#{ca.name}]", format: I18n.t("vehicles.import.format.#{ca.object_type}")}]
    }])
  end

  def columns_vehicle_usage_set
    {
      cost_distance: { title: I18n.t('vehicle_usage_sets.import.cost_distance'), desc: I18n.t('vehicle_usage_sets.import.cost_distance_desc'), format: I18n.t('vehicle_usage_sets.import.format.float') },
      cost_fixed: { title: I18n.t('vehicle_usage_sets.import.cost_fixed'), desc: I18n.t('vehicle_usage_sets.import.cost_fixed_desc'), format: I18n.t('vehicle_usage_sets.import.format.float') },
      cost_time: { title: I18n.t('vehicle_usage_sets.import.cost_time'), desc: I18n.t('vehicle_usage_sets.import.cost_time_desc'), format: I18n.t('vehicle_usage_sets.import.format.float') },
      time_window_start: { title: I18n.t('vehicle_usage_sets.import.time_window_start'), desc: I18n.t('vehicle_usage_sets.import.time_window_start_desc'), format: I18n.t('vehicle_usage_sets.import.format.hour') },
      time_window_end: { title: I18n.t('vehicle_usage_sets.import.time_window_end'), desc: I18n.t('vehicle_usage_sets.import.time_window_end_desc'), format: I18n.t('vehicle_usage_sets.import.format.hour') },
      store_start_ref: { title: I18n.t('vehicle_usage_sets.import.store_start_ref'), desc: I18n.t('vehicle_usage_sets.import.store_start_desc'), format: I18n.t('vehicle_usage_sets.import.format.string') },
      store_stop_ref: { title: I18n.t('vehicle_usage_sets.import.store_stop_ref'), desc: I18n.t('vehicle_usage_sets.import.store_stop_desc'), format: I18n.t('vehicle_usage_sets.import.format.string') },
      rest_start: { title: I18n.t('vehicle_usage_sets.import.rest_start'), desc: I18n.t('vehicle_usage_sets.import.rest_start_desc'), format: I18n.t('vehicle_usage_sets.import.format.hour') },
      rest_stop: { title: I18n.t('vehicle_usage_sets.import.rest_stop'), desc: I18n.t('vehicle_usage_sets.import.rest_stop_desc'), format: I18n.t('vehicle_usage_sets.import.format.hour') },
      rest_duration: { title: I18n.t('vehicle_usage_sets.import.rest_duration'), desc: I18n.t('vehicle_usage_sets.import.rest_duration_desc'), format: I18n.t('vehicle_usage_sets.import.format.hour') },
      store_rest_ref: { title: I18n.t('vehicle_usage_sets.import.store_rest_ref'), desc: I18n.t('vehicle_usage_sets.import.store_rest_desc'), format: I18n.t('vehicle_usage_sets.import.format.string') },
      service_time_start: { title: I18n.t('vehicle_usage_sets.import.service_time_start'), desc: I18n.t('vehicle_usage_sets.import.service_time_start_desc'), format: I18n.t('vehicle_usage_sets.import.format.hour') },
      service_time_end: { title: I18n.t('vehicle_usage_sets.import.service_time_end'), desc: I18n.t('vehicle_usage_sets.import.service_time_end_desc'), format: I18n.t('vehicle_usage_sets.import.format.hour') },
      work_time: { title: I18n.t('vehicle_usage_sets.import.work_time'), desc: I18n.t('vehicle_usage_sets.import.work_time_desc'), format: I18n.t('vehicle_usage_sets.import.format.hour') },
      tags: { title: I18n.t('vehicle_usage_sets.import.tags'), desc: I18n.t('vehicle_usage_sets.import.tags_desc'), format: I18n.t('vehicle_usage_sets.import.tags_format') }
    }
  end

  def columns
    columns_vehicle.merge(columns_vehicle_usage_set)
  end

  def json_to_rows(json)
    json
  end

  def rows_to_json(rows)
    rows
  end

  def before_import(name, data, options)
    @tag_labels = CaseInsensitiveHash[@customer.tags.collect{ |tag| [tag.label, tag] }]
    @tag_ids = CaseInsensitiveHash[@customer.tags.collect{ |tag| [tag.id, tag] }]

    if options[:line_shift] == 1
      # Create missing deliverable units if needed
      column_titles = data[0].is_a?(Hash) ? data[0].keys : data.size > 0 ? data[0].map { |a| a[0] } : []
      unit_labels = @customer.deliverable_units.map(&:label)
      column_titles.each { |capacity_name|
        capacities = Regexp.new("^#{I18n.t('vehicles.import.capacities')}\\[(.*)\\]$").match(capacity_name)
        if capacities && unit_labels.exclude?(capacities[1])
          unit_labels.delete_at(unit_labels.index(capacities[1])) if unit_labels.index(capacities[1])
          @customer.deliverable_units.build(label: capacities[1])
        end
      }
      @customer.save!
    end

    if @customer.default_max_vehicle_usage_sets > 1
      # Use name of the file for default configuration name
      @vehicle_usage_set = @customer.vehicle_usage_sets.build(name: name)
    else
      @vehicle_usage_set = @customer.vehicle_usage_sets.last
    end

    @common_configuration = {}

    @stores_by_ref = CaseInsensitiveHash[@customer.stores.select(&:ref).collect { |store| [store.ref, store] }]

    imported_vehicle_refs = data.map { |datum| datum[I18n.t('vehicles.import.ref_vehicle')] }
    @vehicles_by_ref = CaseInsensitiveHash[@customer.vehicles.select(&:ref).select { |vehicle| imported_vehicle_refs.include?(vehicle.ref) }.collect { |vehicle| [vehicle.ref, vehicle] }]
    @vehicles_without_ref = @customer.vehicles.to_a.select { |vehicle| vehicle.ref.to_s.empty? || !imported_vehicle_refs.include?(vehicle.ref) }
  end

  def prepare_capacities(row)
    capacities = {}
    row.each { |key, _value|
      /^capacity([0-9]+)$/.match(key.to_s) { |m|
        capacities.merge!({ Integer(m[1]) => row.delete(m[0].to_sym) })
      }
    }
    row[:capacities] = capacities if capacities.length > 0
  end

  def prepare_tags(row, key)
    if !row[key].nil?
      if row[key].is_a?(String)
        row[key] = row[key].split(',').uniq.select{ |k|
          !k.empty?
        }
      end

      row[key] = row[key].collect{ |tag|
        if tag.is_a?(Integer)
          @tag_ids[tag]
        else
          tag = tag.strip
          @tag_labels[tag] = @customer.tags.build(label: tag) unless @tag_labels.key?(tag)
          @tag_labels[tag]
        end
      }.compact
    elsif row.key?(key)
      row.delete key
    end
  end

  def prepare_custom_attributes(row)
    custom_attributes = {}
    row.each{ |key, _value|
      Regexp.new("^custom_attributes\\[(.*)\\]$").match(key.to_s) { |m|
        custom_attributes[m[1]] = row.delete(m[0])
      }
    }
    row[:custom_attributes] = custom_attributes if custom_attributes.any?
  end

  def import_row(_name, row, _line, options)
    if (row[:time_window_start].nil? || row[:time_window_end].nil?) && @vehicle_usage_set.nil?
      raise ImportInvalidRow.new(I18n.t('vehicle_usage_sets.import.missing_time_window_start_end'))
    elsif row[:name_vehicle].nil? && !@vehicle_usage_set.nil?
      raise ImportInvalidRow.new(I18n.t('vehicles.import.missing_name'))
    end

    prepare_capacities(row)
    prepare_custom_attributes(row)
    [:tags, :tags_vehicle].each{ |key| prepare_tags(row, key) }

    row[:ref_vehicle] = row[:ref_vehicle]&.strip
    row[:store_start_ref] = row[:store_start_ref]&.strip
    row[:store_stop_ref] = row[:store_stop_ref]&.strip
    row[:store_rest_ref] = row[:store_rest_ref]&.strip

    # For each vehicle, create vehicle and vehicle usage
    vehicle = if !row[:ref_vehicle].nil? && !row[:ref_vehicle].empty? && @vehicles_by_ref[row[:ref_vehicle]]
      @vehicles_by_ref[row[:ref_vehicle]]
    else
      @vehicles_without_ref.shift
    end

    if options[:replace_vehicles]
      vehicle_attributes = row.slice(*columns_vehicle.keys, :capacities, :custom_attributes)
      vehicle_attributes[:ref] = vehicle_attributes.delete(:ref_vehicle)
      vehicle_attributes[:name] = vehicle_attributes.delete(:name_vehicle)
      vehicle_attributes[:color] = vehicle_attributes.delete(:color) || vehicle.color
      vehicle_attributes[:router] = Router.where(mode: vehicle_attributes.delete(:router_mode)).first
      # TODO: use typed options to automatically convert to the correct format
      vehicle_attributes[:router_options] = vehicle_attributes[:router_options] ? ActiveSupport::JSON.decode(vehicle_attributes.delete(:router_options).gsub(/(\d),(\d)/, '\1.\2')) : {}
      vehicle_attributes[:tags] = vehicle_attributes.delete(:tags_vehicle) if vehicle_attributes.key?(:tags_vehicle)
      vehicle_attributes[:devices] = vehicle_attributes[:devices] ? ActiveSupport::JSON.decode(vehicle_attributes.delete(:devices)) : {}
      vehicle.assign_attributes(vehicle_attributes)
    end

    vehicle_usage_attributes = row.slice(*columns_vehicle_usage_set.keys)
    vehicle_usage_attributes[:store_start] = @stores_by_ref[vehicle_usage_attributes.delete(:store_start_ref)]
    vehicle_usage_attributes[:store_stop] = @stores_by_ref[vehicle_usage_attributes.delete(:store_stop_ref)]
    vehicle_usage_attributes[:store_rest] = @stores_by_ref[vehicle_usage_attributes.delete(:store_rest_ref)]
    vehicle_usage = @vehicle_usage_set.vehicle_usages.find{ |vu| vu.vehicle == vehicle }
    vehicle_usage.assign_attributes(vehicle_usage_attributes.except(:name_vehicle_usage_set))

    columns_vehicle_usage_set.keys.each do |key|
      next if key == :tags

      if key == :store_start_ref
        key = :store_start
      elsif key == :store_stop_ref
        key = :store_stop
      elsif key == :store_rest_ref
        key = :store_rest
      end

      if !@common_configuration.key?(key)
        @common_configuration[key] = vehicle_usage_attributes[key]
      elsif @common_configuration[key] != vehicle_usage_attributes[key]
        @common_configuration[key] = nil
      end
    end

    @common_configuration[:max_distance] = vehicle_attributes[:max_distance] if vehicle_attributes
    @common_configuration[:max_ride_distance] = vehicle_attributes[:max_ride_distance] if vehicle_attributes
    @common_configuration[:max_ride_duration] = vehicle_attributes[:max_ride_duration] if vehicle_attributes

    vehicle
  end

  def after_import(_name, _options)
    # If all vehicles have the same parameters, set the parameter to the default configuration and remove it from vehicle
    # Exclude required configuration (rest, service, ...) if all fields not in common
    unless @common_configuration[:time_window_start] && @common_configuration[:time_window_end]
      @common_configuration[:time_window_start] = @common_configuration[:time_window_end] = nil
    end
    unless @common_configuration[:rest_start] && @common_configuration[:rest_stop] && @common_configuration[:rest_duration]
      @common_configuration[:rest_start] = @common_configuration[:rest_stop] = @common_configuration[:rest_duration] = nil
    end
    unless @common_configuration[:service_time_start] && @common_configuration[:service_time_end]
      @common_configuration[:service_time_start] = @common_configuration[:service_time_end] = nil
    end

    @common_configuration.compact!
    unless @common_configuration.keys.empty?
      excluded_keys = %i[max_distance max_ride_distance max_ride_duration]
      @vehicle_usage_set.assign_attributes @common_configuration
      @vehicle_usage_set.vehicle_usages.each{ |vu|
        vu.assign_attributes Hash[@common_configuration.keys.select{ |k| excluded_keys.exclude? k }.map{ |k| [k, nil] }]
      }
      @vehicle_usage_set.import_skip = true
      @vehicle_usage_set.save!
    end

    @customer.save!
  end

  def finalize_import(_name, options)
    options[:dests].each(&:reload)
  end
end
