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
require 'importer_base'
require 'geocoder_destinations_job'
require 'value_to_boolean'

class ImporterDestinations < ImporterBase
  include ConvertDeprecatedHelper
  attr_accessor :plannings

  def initialize(customer, planning_hash = nil)
    super customer
    @provided_planning_attributes = planning_hash || {}
    @deliverable_units = customer&.deliverable_units || []
    @deliverable_unit_hash = customer&.deliverable_units&.map{ |d_u| [d_u.label, d_u] }.to_h || {}
  end

  def max_lines
    @customer.default_max_destinations
  end

  def columns_planning
    {
      planning_ref: {title: I18n.t('destinations.import_file.planning_ref'), desc: I18n.t('destinations.import_file.planning_ref_desc'), format: I18n.t('destinations.import_file.format.string')},
      planning_name: {title: I18n.t('destinations.import_file.planning_name'), desc: I18n.t('destinations.import_file.planning_name_desc'), format: I18n.t('destinations.import_file.format.string')},
      planning_date: {title: I18n.t('destinations.import_file.planning_date'), desc: I18n.t('destinations.import_file.planning_date_desc'), format: I18n.t('destinations.import_file.format.date_desc')},
    }
  end

  def columns_route
    {
      route: {title: I18n.t('destinations.import_file.route'), desc: I18n.t('destinations.import_file.route_desc'), format: I18n.t('destinations.import_file.format.string')},
      ref_vehicle: {title: I18n.t('destinations.import_file.ref_vehicle'), desc: I18n.t('destinations.import_file.ref_vehicle_desc'), format: I18n.t('destinations.import_file.format.string')},
      active: {title: I18n.t('destinations.import_file.active'), desc: I18n.t('destinations.import_file.active_desc'), format: I18n.t('destinations.import_file.format.yes_no')},
      stop_type: {title: I18n.t('destinations.import_file.stop_type'), desc: I18n.t('destinations.import_file.stop_type_desc'), format: I18n.t('destinations.import_file.stop_format')}
    }
  end

  def columns_destination
    destination_columns =
    {
      ref: {title: I18n.t('destinations.import_file.ref'), desc: I18n.t('destinations.import_file.ref_desc'), format: I18n.t('destinations.import_file.format.string')},
      name: {title: I18n.t('destinations.import_file.name'), desc: I18n.t('destinations.import_file.name_desc'), format: I18n.t('destinations.import_file.format.string'), required: I18n.t('destinations.import_file.format.required')},
      street: {title: I18n.t('destinations.import_file.street'), desc: I18n.t('destinations.import_file.street_desc'), format: I18n.t('destinations.import_file.format.string'), required: I18n.t('destinations.import_file.format.advisable')},
      detail: {title: I18n.t('destinations.import_file.detail'), desc: I18n.t('destinations.import_file.detail_desc'), format: I18n.t('destinations.import_file.format.string')},
      postalcode: {title: I18n.t('destinations.import_file.postalcode'), desc: I18n.t('destinations.import_file.postalcode_desc'), format: I18n.t('destinations.import_file.format.integer'), required: I18n.t('destinations.import_file.format.advisable')},
      city: {title: I18n.t('destinations.import_file.city'), desc: I18n.t('destinations.import_file.city_desc'), format: I18n.t('destinations.import_file.format.string'), required: I18n.t('destinations.import_file.format.advisable')}
    }

    destination_columns.merge!(state: {title: I18n.t('destinations.import_file.state'), desc: I18n.t('destinations.import_file.state_desc'), format: I18n.t('destinations.import_file.format.string'), required: I18n.t('destinations.import_file.format.advisable')}) if @customer.with_state?

    destination_columns.merge!({
      country: {title: I18n.t('destinations.import_file.country'), desc: I18n.t('destinations.import_file.country_desc'), format: I18n.t('destinations.import_file.format.string')},
      lat: {title: I18n.t('destinations.import_file.lat'), desc: I18n.t('destinations.import_file.lat_desc'), format: I18n.t('destinations.import_file.format.float')},
      lng: {title: I18n.t('destinations.import_file.lng'), desc: I18n.t('destinations.import_file.lng_desc'), format: I18n.t('destinations.import_file.format.float')},
      phone_number: {title: I18n.t('destinations.import_file.phone_number'), desc: I18n.t('destinations.import_file.phone_number_desc'), format: I18n.t('destinations.import_file.format.integer')},
      comment: {title: I18n.t('destinations.import_file.comment'), desc: I18n.t('destinations.import_file.comment_desc'), format: I18n.t('destinations.import_file.format.string')},
      tags: {title: I18n.t('destinations.import_file.tags'), desc: I18n.t('destinations.import_file.tags_desc'), format: I18n.t('destinations.import_file.tags_format')},
      destination_duration: {title: I18n.t('destinations.import_file.destination_duration'), desc: I18n.t('destinations.import_file.destination_duration_desc'), format: I18n.t('destinations.import_file.format.hour')}
    })

    destination_columns
  end

  def columns_visit
    {
      ref_visit: {title: I18n.t('destinations.import_file.ref_visit'), desc: I18n.t('destinations.import_file.ref_visit_desc'), format: I18n.t('destinations.import_file.format.string')},
      time_window_start_1: {title: I18n.t('destinations.import_file.time_window_start_1'), desc: I18n.t('destinations.import_file.time_window_start_1_desc'), format: I18n.t('destinations.import_file.format.hour')},
      time_window_end_1: {title: I18n.t('destinations.import_file.time_window_end_1'), desc: I18n.t('destinations.import_file.time_window_end_1_desc'), format: I18n.t('destinations.import_file.format.hour')},
      time_window_start_2: {title: I18n.t('destinations.import_file.time_window_start_2'), desc: I18n.t('destinations.import_file.time_window_start_2_desc'), format: I18n.t('destinations.import_file.format.hour')},
      time_window_end_2: {title: I18n.t('destinations.import_file.time_window_end_2'), desc: I18n.t('destinations.import_file.time_window_end_2_desc'), format: I18n.t('destinations.import_file.format.hour')},
      revenue: {title: I18n.t('destinations.import_file.revenue'), desc: I18n.t('destinations.import_file.revenue_desc'), format: I18n.t('destinations.import_file.format.float')},
      priority: {title: I18n.t('destinations.import_file.priority'), desc: I18n.t('destinations.import_file.priority_desc'), format: I18n.t('destinations.import_file.format.integer')},
      force_position: {title: I18n.t('destinations.import_file.force_position'), desc: I18n.t('destinations.import_file.force_position_desc'), format: I18n.t('destinations.import_file.force_position_format')},
      tag_visits: {title: I18n.t('destinations.import_file.tags_visit'), desc: I18n.t('destinations.import_file.tags_visit_desc'), format: I18n.t('destinations.import_file.tags_format')},
      duration: {title: I18n.t('destinations.import_file.duration'), desc: I18n.t('destinations.import_file.duration_desc'), format: I18n.t('destinations.import_file.format.hour')},
    }.merge(Hash[@deliverable_units.flat_map{ |du|
      [
        ["quantity#{du.id}".to_sym, {title: I18n.t('destinations.import_file.quantity') + (du.label ? "[#{du.label}]" : "#{du.id}"), desc: I18n.t('destinations.import_file.quantity_desc'), format: I18n.t('destinations.import_file.format.float')}],
        ["pickup#{du.id}".to_sym, {title: I18n.t('destinations.import_file.pickup') + (du.label ? "[#{du.label}]" : "#{du.id}"), desc: I18n.t('destinations.import_file.pickup_desc'), format: I18n.t('destinations.import_file.format.float')}],
        ["delivery#{du.id}".to_sym, {title: I18n.t('destinations.import_file.delivery') + (du.label ? "[#{du.label}]" : "#{du.id}"), desc: I18n.t('destinations.import_file.delivery_desc'), format: I18n.t('destinations.import_file.format.float')}],
      ]
    }]).merge(Hash[@customer.custom_attributes.for_visit.map { |ca|
    ["custom_attributes_visit[#{ca.name}]", { title: "#{I18n.t('destinations.import_file.custom_attributes_visit')}[#{ca.name}]", format: I18n.t("destinations.import_file.format.#{ca.object_type}")}]
  }])
  end

  def columns_store
    columns_destination.except(:detail, :phone_number, :comment, :tags, :destination_duration)
  end

  def columns
    @columns ||= import_columns
  end

  def import_columns
    columns_planning.merge(columns_route).merge(columns_destination).merge(columns_visit).merge(
      without_visit: {title: I18n.t('destinations.import_file.without_visit'), desc: I18n.t('destinations.import_file.without_visit_desc'), format: I18n.t('destinations.import_file.format.yes_no')},
      # Deals with deprecated quantities replaced by pickups and deliveries
      quantities: {}, # only for json import
      # Deals with deprecated open and close
      open: {title: I18n.t('destinations.import_file.open'), desc: I18n.t('destinations.import_file.open_desc'), format: I18n.t('destinations.import_file.format.hour'), required: I18n.t('destinations.import_file.format.deprecated')},
      close: {title: I18n.t('destinations.import_file.close'), desc: I18n.t('destinations.import_file.close_desc'), format: I18n.t('destinations.import_file.format.hour'), required: I18n.t('destinations.import_file.format.deprecated')},
      # Deals with deprecated quantity
      quantity: {title: I18n.t('destinations.import_file.quantity'), desc: I18n.t('destinations.import_file.quantity_desc'), format: I18n.t('destinations.import_file.format.integer'), required: I18n.t('destinations.import_file.format.deprecated')},
      quantity1_1: {title: I18n.t('destinations.import_file.quantity1_1'), desc: I18n.t('destinations.import_file.quantity1_1_desc'), format: I18n.t('destinations.import_file.format.integer'), required: I18n.t('destinations.import_file.format.deprecated')},
      quantity1_2: {title: I18n.t('destinations.import_file.quantity1_2'), desc: I18n.t('destinations.import_file.quantity1_2_desc'), format: I18n.t('destinations.import_file.format.integer'), required: I18n.t('destinations.import_file.format.deprecated')},
    )
  end

  # convert json with multi visits in several rows like in csv
  def json_to_rows(json)
    json.collect{ |dest|
      dest[:tags] = dest[:tag_ids].collect(&:to_i) if dest[:tags].blank? && dest.key?(:tag_ids)
      if dest.key?(:visits) && !dest[:visits].empty?
        dest[:visits].collect{ |v|
          v[:ref_visit] = v.delete(:ref)
          v[:tag_visits] = v[:tag_ids]&.map(&:to_i) || []
          v[:tag_visits] += v[:tags] if v[:tags]&.any?
          v.delete(:tags)
          v[:tag_visits].uniq!
          if v[:quantities] && v[:quantities].is_a?(Array)
            pickup_hash = {}
            delivery_hash = {}
            v[:quantities].map{ |q|
              if q[:deliverable_unit_label] && !q[:deliverable_unit_id]
                du = @deliverable_unit_hash[q[:deliverable_unit_label]] || @customer.deliverable_units.create(label: q[:deliverable_unit_label])
                @deliverable_unit_hash[q[:deliverable_unit_label]] = du
                q[:deliverable_unit_id] = du.id
              end
              pickup_hash[q[:deliverable_unit_id]] = q[:pickup]
              delivery_hash[q[:deliverable_unit_id]] = q[:delivery]
            }
            v[:pickups] = pickup_hash
            v[:deliveries] = delivery_hash
          end
          dest.except(:visits).merge(v)
        }
      elsif dest.key?(:visits) && dest[:visits].empty?
        [dest.merge(without_visit: 'x')]
      else
        [dest.merge(without_visit: 'y')] # Import without visit but without a destroy neither
      end
    }.flatten
  end

  def rows_to_json(rows)
    @customer.destinations.includes(:visits).where(id: @destination_ids)
  end

  def before_import(_name, data, options)
    @common_tags = {}
    @tag_labels = Hash[@customer.tags.collect{ |tag| [tag.label, tag] }]
    @tag_ids = Hash[@customer.tags.collect{ |tag| [tag.id, tag] }]
    @plannings_routes = Hash.new{ |h, k|
      h[k] = Hash.new{ |hh, kk|
        hh[kk] = Hash.new{ |hhh, kkk|
          hhh[kkk] = kkk == :visits ? [] : nil
        }
      }
    }
    @plannings_vehicles = Hash.new{ |h, k|
      h[k] = Hash.new
    }
    @deliverable_units ||= @customer&.deliverable_units || []
    @destinations_to_geocode_count = 0
    @stores_to_geocode_count = 0
    @visit_ids = []

    if options[:delete_plannings]
      @customer.plannings.delete_all
      @customer.plannings.reload
    end
    if options[:replace]
      @customer.delete_all_destinations
    end
    @plannings_hash = Hash[@customer.plannings.select(&:ref).map{ |plan| [plan.ref.downcase.to_sym, plan] }]

    if options[:line_shift] == 1
      labels = %w[delivery pickup quantity]
      # Create missing deliverable units if needed
      column_titles = data[0].is_a?(Hash) ? data[0].keys : data.size > 0 ? data[0].map{ |a| a[0] } : []
      unit_labels = @deliverable_units.map(&:label)
      column_titles.each{ |name|
        labels.each{ |label|
          m = Regexp.new("^" + I18n.t("destinations.import_file.#{label}") + "\\[(.*)\\]$").match(name)
          if m && unit_labels.exclude?(m[1])
            @deliverable_units << @customer.deliverable_units.create(label: m[1])
            unit_labels << m[1]
            @deliverable_unit_hash[m[1]] = @deliverable_units.last
            @columns = nil # Reset columns "cache"
          end
        }
      }
      @customer.save!
    end

    @destinations_attributes_without_ref = []
    @stores_attributes_without_ref = []
    @existing_destinations_by_ref = {}
    @existing_visits_by_ref = {}
    @existing_stores_by_ref = {}
    @destinations_visits_attributes_by_ref = {}
    @customer.destinations.includes_visits.where.not(ref: nil).find_each{ |destination|
      @existing_destinations_by_ref[destination.ref.to_sym] = destination
      @existing_visits_by_ref[destination.ref.to_sym] = Hash[destination.visits.map{ |visit| [visit.ref&.to_sym, visit]}]
      @destinations_visits_attributes_by_ref[destination.ref.to_sym] = Hash.new
      destination.visits.each{ |visit| @destinations_visits_attributes_by_ref[visit.destination.ref&.to_sym][visit.ref&.to_sym] = visit }
    }
    @customer.stores.where.not(ref: nil).find_each{ |store|
      @existing_stores_by_ref[store.ref.to_sym] = store
    }

    @destinations_visits_attributes_by_ref[nil] = Hash.new
    @destinations_attributes_by_ref = {}
    @stores_attributes_by_ref = {}
    @visits_attributes_with_destination = {}
    @visits_attributes_without_ref = []
    @visits_attributes_without_destination_with_ref_visit = {}
    @visits_attributes_without_destination_without_ref_visit = {}
    @visits_attributes_with_destination_with_ref_visit = {}
    @visits_attributes_with_destination_without_ref_visit = {}

    # @plannings_by_ref set in import_row in order to have internal row title
    @plannings_by_ref = {}
    @@col_dest_keys ||= columns_destination.keys + [:tag_ids]
    @col_visit_keys = columns_visit.keys + [:tag_visit_ids, :pickups, :deliveries, :custom_attributes_visit]
    @@col_store_keys = columns_store.keys
    @@slice_attr ||= (@@col_dest_keys - [:customer_id, :lat, :lng]).collect(&:to_s)

    # Used tp link rows to objects created through bulk imports
    @destination_index_to_id_hash = {}
    @visit_index_to_id_hash = {}
    @store_index_to_id_hash = {}
    @destination_index = 0
    @visit_index = 0
    @store_index = 0

    @nil_visit_available = Hash.new(Hash.new(true))

    @tag_destinations = []
    @tag_visits = []

    @plannings = []
    @plannings_attributes = {}
  end

  def uniq_ref(row)
    row[:stop_type] = row[:stop_type].present? ? valid_stop_type(row[:stop_type]) : I18n.t('destinations.import_file.stop_type_visit')
    return if row.key?(:stop_type) && row[:stop_type] != I18n.t('destinations.import_file.stop_type_visit')
    row[:ref] || row[:ref_visit] ? [row[:ref], row[:ref_visit]] : nil
  end

  def prepare_quantities(row)
    # Handle quantity[x] columns
    q = {}
    row.each{ |key, value|
      /^quantity([0-9]+)$/.match(key.to_s) { |m|
        q.merge! Integer(m[1]) => CoerceFloatString.parse(row.delete(m[0].to_sym))
      }
    }
    row[:quantities] = q unless q.empty?

    # Handle pickup[x] columns
    p = {}
    row.each{ |key, value|
      /^pickup([0-9]+)$/.match(key.to_s) { |m|
        p.merge! Integer(m[1]) => CoerceFloatString.parse(row.delete(m[0].to_sym))
      }
    }
    row[:pickups] = p unless p.empty?

    # Handle delivery[x] columns
    d = {}
    row.each{ |key, value|
      /^delivery([0-9]+)$/.match(key.to_s) { |m|
        d.merge! Integer(m[1]) => CoerceFloatString.parse(row.delete(m[0].to_sym))
      }
    }
    row[:deliveries] = d unless d.empty?

    # Deals with deprecated quantity columns
    convert_deprecated_quantities(row, @deliverable_units)

    # handle grape format
    if row[:quantities]
      row[:deliveries] ||= {}
      row[:pickups] ||= {}
      if row[:quantities].is_a?(Array)
        row[:quantities].each{ |quantity|
          row[:deliveries][quantity[:deliverable_unit_id]] = quantity[:delivery] if quantity[:delivery]
          row[:pickups][quantity[:deliverable_unit_id]] = quantity[:pickup] if quantity[:pickup]
        }
      else
        row[:quantities].each{ |unit_id, quantity|
          row[:pickups][unit_id] = Float(quantity).abs if quantity && Float(quantity) < 0
          row[:deliveries][unit_id] = Float(quantity) if quantity && Float(quantity) > 0
        }
      end
      row.delete(:quantities)
    end
  end

  def merge_visit_quantities(existing_visit, visit_attributes)
    # Merge pickups
    ((existing_visit&.dig(:pickups)&.keys || []) + (visit_attributes&.dig(:pickups)&.keys || [])).uniq.each{ |key|
      next unless visit_attributes&.dig(:pickups, key) || existing_visit&.dig(:pickups, key)

      visit_attributes[:pickups] ||= {}
      visit_attributes[:pickups][key] = (visit_attributes&.dig(:pickups, key) || 0) + (existing_visit&.dig(:pickups, key) || 0)
    }

    # Merge deliveries
    ((existing_visit&.dig(:deliveries)&.keys || []) + (visit_attributes&.dig(:deliveries)&.keys || [])).uniq.each{ |key|
      next unless visit_attributes&.dig(:deliveries, key) || existing_visit&.dig(:deliveries, key)

      visit_attributes[:deliveries] ||= {}
      visit_attributes[:deliveries][key] = (visit_attributes&.dig(:deliveries, key) || 0) + (existing_visit&.dig(:deliveries, key) || 0)
    }
  end

  def prepare_tags(row, key)
    key_s = "#{key}s".to_sym
    key_ids = "#{key}_ids".to_sym
    if !row[key_s].nil?
      if row[key_s].is_a?(String)
        row[key_s] = row[key_s].split(',').uniq.select{ |key|
          !key.empty?
        }
      end

      row[key_ids] = row[key_s].collect{ |tag|
        if tag.is_a?(Integer) && @tag_ids.key?(tag)
          tag
        else
          tag = tag.strip if tag.is_a?(String)
          if !@tag_labels.key?(tag)
            @tag_labels[tag] = @customer.tags.create(label: tag)
          end
          @tag_labels[tag].id
        end
      }.compact
      row.delete(key_s)
    end
    if row.key?(key_s)
      row.delete(key_s)
    end
  end

  def prepare_custom_attributes(row)
    custom_attributes_visit = {}
    row.each{ |key, _value|
      Regexp.new("^custom_attributes_visit\\[(.*)\\]$").match(key.to_s) { |m|
        custom_attributes_visit[m[1]] = row.delete(m[0])
      }
    }
    row[:custom_attributes_visit] = custom_attributes_visit if custom_attributes_visit.any?
  end

  def valid_row(destination)
    if destination.name.nil?
      raise ImportInvalidRow.new(I18n.t('destinations.import_file.missing_name'))
    end
    if destination.city.nil? && destination.postalcode.nil? && (destination.lat.nil? || destination.lng.nil?)
      raise ImportInvalidRow.new(I18n.t('destinations.import_file.missing_location'))
    end
  end

  def valid_stop_type(stop_type)
    type = nil
    %w(store visit rest).each do |t|
      type ||= t if stop_type == I18n.t("activerecord.models.stops.type.#{t}")
    end
    if type
      I18n.t("activerecord.models.stops.type.#{type}")
    else
      raise ImportInvalidRow.new(I18n.t('destinations.import_file.invalid_stop'))
    end
  end

  def convert_force_position(force_position)
    type = nil
    Visit.force_positions.each do |key, index|
      type ||= index if force_position == key || force_position == I18n.t("activerecord.models.visits.force_position.#{key}")
    end
    type || 0
  end

  def is_visit?(type)
    type == I18n.t('destinations.import_file.stop_type_visit') || type == 'visit' || type.blank?
  end

  def is_store?(type)
    type == I18n.t('destinations.import_file.stop_type_store') || type == 'store'
  end

  def import_row(_name, row, line, _options)
    if is_visit?(row[:stop_type])
      convert_deprecated_fields(row)
      convert_localized_fields(row) # Necessary as import do not use validation callbacks
      prepare_quantities(row)
      prepare_custom_attributes(row)

      [:tag, :tag_visit].each{ |key| prepare_tags(row, key) }
      destination_attributes, visit_attributes = build_attributes(row)

      prepare_destination(row, line, destination_attributes, visit_attributes)
      prepare_destination_in_planning(row, line, destination_attributes, visit_attributes)
      destination_attributes
    elsif is_store?(row[:stop_type])
      return nil unless @customer.enable_store_stops

      store_attributes = build_store_attributes(row)
      prepare_store(row, line, store_attributes)
      prepare_store_in_planning(row, line, store_attributes)
      store_attributes
    end
  end

  def after_import(name, _options)
    @destination_ids = bulk_import_destinations(@destinations_attributes_without_ref)
    @destination_ids += bulk_import_destinations(@destinations_attributes_by_ref.values)
    # bulk import do not support before_create or before_save callbacks
    if @customer.destinations.size > max_lines
      raise(Exceptions::OverMaxLimitError.new(I18n.t('activerecord.errors.models.customer.attributes.destinations.over_max_limit')))
    end
    @visit_ids = bulk_import_visits
    bulk_import_tags
    @store_ids = bulk_import_stores
    @customer.reload

    geocode_or_count_destinations
    geocode_or_count_stores

    prepare_plannings(name, _options)

    # Update destinations_count and visits_count as activerecord callbacks are not called
    Customer.where(id: @customer.id).update_all(
      destinations_count: @customer.destinations.count,
      plannings_count: @customer.plannings.count,
      vehicles_count: @customer.vehicles.count,
      visits_count: Visit.joins(:destination).where(destinations: { customer_id: @customer.id }).count
    )
  end

  def geocode_or_count_destinations
    @destinations_to_geocode_count = @customer.destinations.not_positioned.count
    if @destinations_to_geocode_count > 0 && (@synchronous || !Planner::Application.config.delayed_job_use)
      @customer.destinations.includes_visits.not_positioned.find_in_batches(batch_size: 50){ |destinations|
        geocode_args = destinations.collect(&:geocode_args)
        begin
          results = Planner::Application.config.geocoder.code_bulk(geocode_args)
          destinations.zip(results).each { |destination, result|
            if result
              destination.geocode_result(result)
              destination.save
            end
          }
        rescue GeocodeError # avoid stop import because of geocoding job
        end
      }
    end
  end

  def geocode_or_count_stores
    @stores_to_geocode_count = @customer.stores.not_positioned.count
    if @stores_to_geocode_count > 0 && (@synchronous || !Planner::Application.config.delayed_job_use)
      @customer.stores.not_positioned.find_in_batches(batch_size: 50){ |stores|
        geocode_args = stores.collect(&:geocode_args)
        begin
          results = Planner::Application.config.geocoder.code_bulk(geocode_args)
          stores.zip(results).each { |store, result|
            if result
              store.geocode_result(result)
              store.save
            end
          }
        rescue GeocodeError # avoid stop import because of geocoding job
        end
      }
    end
  end

  def save_plannings
    Route.no_touching do
      @plannings.each { |planning|
        if !planning.id
          planning.save_import!
        else
          planning.save!
        end
        planning.reload
      }
    end
  end

  def finalize_import(_name, _options)
    if (@destinations_to_geocode_count > 0 || @stores_to_geocode_count > 0) && (!@synchronous && Planner::Application.config.delayed_job_use)
      save_plannings
      @customer.job_destination_geocoding = Delayed::Job.enqueue(GeocoderJob.new(@customer.id, !@plannings.empty? ? @plannings.map(&:id) : nil))
    elsif !@plannings.empty?
      save_plannings
      @plannings.each{ |planning|
        planning.compute_saved(ignore_errors: true)
      }
    end
    @customer.save! && @customer.reload
  end

  private

  def convert_deprecated_fields(row)
    ## TODO: Manage it in API input :
    # Deals with deprecated open and close
    row[:time_window_start_1] = row.delete(:open) if !row.key?(:time_window_start_1) && row.key?(:open)
    row[:time_window_end_1] = row.delete(:close) if !row.key?(:time_window_end_1) && row.key?(:close)

    # Deals with deprecated time_window_start_1/2 and time_window_end_1/2
    row[:time_window_start_1] = row.delete(:time_window_start_1) if !row.key?(:time_window_start_1) && row.key?(:time_window_start_1)
    row[:time_window_end_1] = row.delete(:time_window_end_1) if !row.key?(:time_window_end_1) && row.key?(:time_window_end_1)
    row[:time_window_start_2] = row.delete(:time_window_start_2) if !row.key?(:time_window_start_2) && row.key?(:time_window_start_2)
    row[:time_window_end_2] = row.delete(:time_window_end_2) if !row.key?(:time_window_end_2) && row.key?(:time_window_end_2)

    # Deals with deprecated take_over
    row[:duration] = row.delete(:duration) if !row.key?(:duration) && row.key?(:duration)
  end

  def convert_localized_fields(row)
    row[:revenue] = row[:revenue].gsub(/,/, '.')&.to_f if row[:revenue].is_a?(String)
  end

  def build_store_attributes(row)
    # Convert references to symbol
    row[:planning_ref] = row[:planning_ref]&.strip&.to_sym
    ref_planning = row[:planning_ref].blank? ? nil : row[:planning_ref].downcase
    row[:ref] = row[:ref]&.strip&.to_sym
    row.delete(:planning_date) if row[:planning_date] == ""

    @plannings_attributes[ref_planning] ||=
      {
        ref: row[:planning_ref],
        name: row[:planning_name],
        date: row[:planning_date] && custom_date_parse(row[:planning_date]) || Date.today + @customer.planning_date_offset,
        customer: @customer,
        vehicle_usage_set: @customer.vehicle_usage_sets[0]
      }

    store_attributes = row.slice(*(@@col_store_keys)).merge(customer_id: @customer.id)
    store_attributes[:store_index] = @store_index
    store_attributes
  end

  def build_attributes(row)
    # Convert references to symbol
    row[:planning_ref] = row[:planning_ref]&.strip&.to_sym
    ref_planning = row[:planning_ref].blank? ? nil : row[:planning_ref].downcase
    row[:ref] = row[:ref]&.strip&.to_sym
    row[:ref_visit] = row[:ref_visit]&.strip&.to_sym if row.key?(:ref_visit)
    row.delete(:planning_date) if row[:planning_date] == ""

    @plannings_attributes[ref_planning] ||=
      {
        ref: row[:planning_ref],
        name: row[:planning_name],
        date: row[:planning_date] && custom_date_parse(row[:planning_date]) || Date.today + @customer.planning_date_offset,
        customer: @customer,
        vehicle_usage_set: @customer.vehicle_usage_sets[0]
      }

    destination_attributes = row.slice(*(@@col_dest_keys)).merge(customer_id: @customer.id)
    destination_attributes[:duration] = destination_attributes.delete :destination_duration
    convert_lat_lng_attributes(destination_attributes)
    visit_attributes = row.slice(*@col_visit_keys)
    visit_attributes[:ref] = visit_attributes.delete :ref_visit
    visit_attributes[:tag_ids] = visit_attributes.delete(:tag_visit_ids)
    visit_attributes[:priority] = nil if visit_attributes[:priority].to_i == 0
    visit_attributes[:custom_attributes] = visit_attributes.delete :custom_attributes_visit if visit_attributes.key?(:custom_attributes_visit)
    visit_attributes[:force_position] = convert_force_position(row[:force_position]) if row[:force_position].present?
    visit_attributes[:visit_index] = @visit_index
    @visit_index += 1
    [destination_attributes, visit_attributes]
  end

  def convert_lat_lng_attributes(destination_attributes)
    return if !destination_attributes.key?(:lat) && !destination_attributes.key?(:lng)

    destination_attributes[:lat] =
      if destination_attributes[:lat].nil? || destination_attributes[:lat] == ''
        nil
      else
        destination_attributes[:lat].gsub!(',', '.') if destination_attributes[:lat].is_a? String
        destination_attributes[:lat].to_f
      end
    destination_attributes[:lng] =
      if destination_attributes[:lng].nil? || destination_attributes[:lng] == ''
        nil
      else
        destination_attributes[:lng].gsub!(',', '.') if destination_attributes[:lng].is_a? String
        destination_attributes[:lng].to_f
      end
  end

  def reset_geocoding(destination_attributes)
    # As import has no create or update callback apply `delay_geocode` manually
    if destination_attributes.key?(:lat) || destination_attributes.key?(:lng)
      destination_attributes[:geocoding_result] = {}
      destination_attributes[:geocoding_accuracy] = nil
      destination_attributes[:geocoding_level] =
        destination_attributes.key?(:lat) && destination_attributes.key?(:lng) ? 1 : nil
    end
  end

  def bulk_import_destinations(destination_index_attributes_hash)
    return [] if destination_index_attributes_hash.empty?

    # Every entry should have identical keys to be imported at the same time
    destination_index_attributes_hash.group_by{ |import_index, lines, attributes|
      attributes.keys
    }.flat_map{ |_keys, index_attributes|
      ids = []
      # Slice to reduce memory spike
      index_attributes.each_slice(1000).with_index{ |sliced_attributes, slice_index|
        destination_import_indices = []
        slice_lines = []
        destinations_attributes = sliced_attributes.map{ |import_index, lines, attributes|
          attributes.delete(:tag_ids)&.each{ |tag_id|
            @tag_destinations << [import_index, tag_id]
          }
          slice_lines << lines
          destination_import_indices << import_index
          attributes
        }
        import_result = Destination.import(
          destinations_attributes,
          on_duplicate_key_update: { conflict_target: [:id], columns: :all },
          validate: true, all_or_none: true, track_validation_failures: true,
          validate_with_context: :import
        )

        raise ImportBulkError.new(import_errors_with_indices(slice_lines, slice_index, import_result.failed_instances)) if import_result.failed_instances.any?

        import_result.ids.each.with_index{ |id, index|
          @destination_index_to_id_hash[destination_import_indices[index]] = id
        }
        ids += import_result.ids
      }
      ids
    }
  end

  def bulk_import_visits
    # Every entry should have identical keys to be imported at the same time
    (
      @visits_attributes_without_ref +
      @visits_attributes_without_destination_without_ref_visit.flat_map{ |k, dest_visits| dest_visits } +
      @visits_attributes_without_destination_with_ref_visit.flat_map{ |k, dest_visit_hash| dest_visit_hash.values } +
      @visits_attributes_with_destination_without_ref_visit.flat_map{ |k, dest_visits| dest_visits } +
      @visits_attributes_with_destination_with_ref_visit.flat_map{ |k, dest_visit_hash| dest_visit_hash.values }
    ).group_by{ |lines, attributes|
      attributes.keys
    }.flat_map{ |keys, key_attributes|
      ids = []
      # Slice to reduce memory spike
      key_attributes.each_slice(1000).with_index { |sliced_attributes, slice_index|
        visit_import_indices = []
        slice_lines = []
        visits_attributes = sliced_attributes.map{ |lines, attributes|
          attributes.delete(:tag_ids)&.each{ |tag_id|
            @tag_visits << [attributes[:visit_index], tag_id]
          }
          slice_lines << lines
          visit_import_indices << attributes[:visit_index]
          attributes[:destination_id] = @destination_index_to_id_hash[attributes.delete(:destination_index)] if attributes.key?(:destination_index)
          attributes.except(:visit_index)
        }

        import_result = Visit.import(
          visits_attributes,
          on_duplicate_key_update: { conflict_target: (keys.include?(:id) ? [:id] : [:destination_id, :ref]), columns: (Visit.column_names & keys.collect(&:to_s)) - ['id', 'updated_at'] },
          validate: true, all_or_none: true, track_validation_failures: true
        )

        raise ImportBulkError.new(import_errors_with_indices(slice_lines, slice_index, import_result.failed_instances)) if import_result.failed_instances.any?

        import_result.ids.each.with_index{ |id, index|
          @visit_index_to_id_hash[visit_import_indices[index]] = id
        }
        ids += import_result.ids
      }
      ids
    }
  end

  def bulk_import_stores
    # Every entry should have identical keys to be imported at the same time
    (
      @stores_attributes_without_ref +
      @stores_attributes_by_ref.values
    ).group_by{ |import_index, lines, attributes|
      attributes.keys
    }.flat_map{ |keys, key_attributes|

      ids = []

      # Slice to reduce memory spike
      key_attributes.each_slice(1000).with_index { |sliced_attributes, slice_index|
        store_import_indices = []
        slice_lines = []
        stores_attributes = sliced_attributes.map{ |import_index, lines, attributes|
          slice_lines << lines
          store_import_indices << import_index
          attributes.except(:store_index)
        }

        import_result = Store.import(
          stores_attributes,
          on_duplicate_key_update: { conflict_target: [:id], columns: :all },
          validate: true, all_or_none: true, track_validation_failures: true,
          validate_with_context: :import
        )

        raise ImportBulkError.new(import_errors_with_indices(slice_lines, slice_index, import_result.failed_instances)) if import_result.failed_instances.any?

        import_result.ids.each.with_index{ |id, index|
          @store_index_to_id_hash[store_import_indices[index]] = id
        }
        ids += import_result.ids
      }
      ids
    }
  end

  def bulk_import_tags
    if @tag_destinations.any?
      destination_ids_and_tag_ids = @tag_destinations.map{ |visit_index, tag_id|
        { destination_id: @destination_index_to_id_hash[visit_index], tag_id: tag_id }
      }
      import_result = TagDestination.import(
        destination_ids_and_tag_ids,
        on_duplicate_key_ignore: true
      )
      raise ImportBaseError.new(import_result.failed_instances.map(&:errors).uniq) if import_result.failed_instances.any?

      if @customer.plannings.any?
        @customer.destinations.joins(:tags).where(
          id: destination_ids_and_tag_ids.map{ |tag| tag[:destination_id] }.uniq).where(
          tags: { id: destination_ids_and_tag_ids.map{ |tag| tag[:tag_id] }.uniq }
        ).distinct.find_each{ |destination|
          destination.update_tags_track(true)
          destination.save!
        }
        @customer.save!
      end
    end
    if @tag_visits.any?
      visit_ids_and_tag_ids = @tag_visits.map{ |visit_index, tag_id|
        { visit_id: @visit_index_to_id_hash[visit_index], tag_id: tag_id }
      }
      import_result = TagVisit.import(
        visit_ids_and_tag_ids,
        on_duplicate_key_ignore: true
      )
      raise ImportBaseError.new(import_result.failed_instances.map(&:errors).uniq) if import_result.failed_instances.any?

      if @customer.plannings.any?
        # Default scope requires destinations to be loaded
        Destination.unscoped do
          @customer.visits.joins(:tags).where(
            id: visit_ids_and_tag_ids.map{ |tag| tag[:visit_id] }.uniq).where(
            tags: { id: visit_ids_and_tag_ids.map{ |tag| tag[:tag_id] }.uniq }
          ).distinct.find_each{ |visit|
            visit.update_tags_track(true)
            visit.save!
          }
        end
        @customer.save!
      end
    end
  end

  def prepare_store(row, line, store_attributes)
    if row[:ref].present? && !row[:ref].empty?
      store = @existing_stores_by_ref[row[:ref]]
      if store
        store_attr = store.attributes.symbolize_keys
        store_attributes = store_attr.extract!(:id, :name, :postalcode, :city, :lat, :lng).merge(store_attributes)
      end
      index, lines, store_attr = @stores_attributes_by_ref[row[:ref]]
      if store_attr
        reset_geocoding(store_attributes)
        lines << line
        store_attributes = store_attr.merge(store_attributes.compact)
      else
        index = @store_index
        reset_geocoding(store_attributes)
        @stores_attributes_by_ref[row[:ref]] = [index, [line], store_attributes]
        @store_index += 1
      end
    else
      @stores_attributes_without_ref << [@store_index, [line], store_attributes]
      @store_index += 1
    end
  end

  def prepare_destination(row, line, destination_attributes, visit_attributes)
    if row[:ref].present? && !row[:ref].empty?
      destination =  @existing_destinations_by_ref[row[:ref]]
      if destination
        dest_attributes = destination.attributes.symbolize_keys
        destination_attributes = dest_attributes.extract!(:id, :name, :postalcode, :city, :lat, :lng).merge(destination_attributes)
      end
      index, lines, dest_attributes = @destinations_attributes_by_ref[row[:ref]]
      if dest_attributes
        reset_geocoding(destination_attributes)
        lines << line
        destination_attributes = dest_attributes.merge(destination_attributes.compact)
      else
        index = @destination_index
        reset_geocoding(destination_attributes)
        @destinations_attributes_by_ref[row[:ref]] = [@destination_index, [line], destination_attributes]
        @destination_index += 1
      end
      prepare_visit_with_destination_ref(row, line, destination, index, destination_attributes, visit_attributes) if index
    else
      @destinations_attributes_without_ref << [@destination_index, [line], destination_attributes]
      prepare_visit_without_destination_ref(row, line, @destination_index, destination_attributes, visit_attributes)
      @destination_index += 1
    end
  end

  def prepare_visit_with_destination_ref(row, line, destination, destination_index, destination_attributes, visit_attributes)
    if row[:without_visit].nil? || row[:without_visit].strip.empty?
      if destination
        ref_planning = row[:planning_ref].blank? ? nil : row[:planning_ref].downcase
        visit = if row[:ref_visit] || @nil_visit_available[ref_planning][row[:ref]]
                  # If nil_visit available retrieve the first visit of the destination with a nil ref_visit
                  @nil_visit_available[ref_planning][row[:ref]] = false
                  @existing_visits_by_ref[row[:ref]][row[:ref_visit]]
        end
        @destinations_visits_attributes_by_ref[destination.ref] ||= Hash.new
        visit_attributes.merge!(destination_id: destination.id)
        if visit
          visit_attributes.merge!(id: visit.id)
          # The visit is assumed to be changed
          # TODO: Find a way to call the `update_outdated` callback during the transaction
          visit.outdated

          # Compact allows to avoid erasing nil fields
          visit_attributes.compact!
        end

        if row[:ref_visit]
          @visits_attributes_with_destination_with_ref_visit[row[:ref]] = {} if !@visits_attributes_with_destination_with_ref_visit.key?(row[:ref])
          lines = (@visits_attributes_with_destination_with_ref_visit[row[:ref]][row[:ref_visit]]&.first || []) << line
          merge_visit_quantities(@visits_attributes_with_destination_with_ref_visit[row[:ref]][row[:ref_visit]]&.last, visit_attributes)
          @visits_attributes_with_destination_with_ref_visit[row[:ref]][row[:ref_visit]] = [lines, visit_attributes]
        else
          @visits_attributes_with_destination_without_ref_visit[row[:ref]] = [] if !@visits_attributes_with_destination_without_ref_visit.key?(row[:ref])
          @visits_attributes_with_destination_without_ref_visit[row[:ref]] << [[line], visit_attributes]
        end
      else
        visit_attributes.merge!(destination_index: destination_index)
        if row[:ref_visit]
          @visits_attributes_without_destination_with_ref_visit[row[:ref]] = {} if !@visits_attributes_without_destination_with_ref_visit.key?(row[:ref])
          lines = (@visits_attributes_without_destination_with_ref_visit[row[:ref]][row[:ref_visit]]&.first || []) << line
          merge_visit_quantities(@visits_attributes_without_destination_with_ref_visit[row[:ref]][row[:ref_visit]]&.last, visit_attributes)
          @visits_attributes_without_destination_with_ref_visit[row[:ref]][row[:ref_visit]] = [lines, visit_attributes]
        else
          @visits_attributes_without_destination_without_ref_visit[row[:ref]] = [] if !@visits_attributes_without_destination_without_ref_visit.key?(row[:ref])
          @visits_attributes_without_destination_without_ref_visit[row[:ref]] << [[line], visit_attributes]
        end
      end
    elsif row[:without_visit] == 'x'
      destination&.visits&.destroy_all
    end
  end

  def prepare_visit_without_destination_ref(row, line, destination_index, destination_attributes, visit_attributes)
    @visits_attributes_without_ref << [[line], visit_attributes.merge(destination_index: destination_index)]
  end

  def prepare_store_in_planning(row, line, store_attributes)
    return if !@customer.enable_store_stops
    if store_attributes
      ref_planning = row[:planning_ref].blank? ? nil : row[:planning_ref].downcase
      if row.key?(:route) && store_attributes[:id].nil?
        ref_route = row[:route].blank? ? nil : row[:route].downcase # ref has to be nil for out-of-route
        if ref_route && row[:ref_vehicle]
          ref_vehicle = row[:ref_vehicle].gsub(%r{[\./\\]}, ' ').downcase
          if @plannings_routes[ref_planning][ref_route].key?(:ref_vehicle) &&
             @plannings_routes[ref_planning][ref_route][:ref_vehicle] != ref_vehicle ||
             @plannings_vehicles[ref_planning][ref_vehicle] &&
             @plannings_vehicles[ref_planning][ref_vehicle] != ref_route
            raise ImportInvalidRow.new(I18n.t('destinations.import_file.refs_route_discordant'))
          end
          @plannings_routes[ref_planning][ref_route][:ref_vehicle] = ref_vehicle
          @plannings_vehicles[ref_planning][ref_vehicle] = ref_route
        end
        @plannings_routes[ref_planning][ref_route][:visits] << [:store, store_attributes, true]
      end
    end
  end

  def prepare_destination_in_planning(row, line, destination_attributes, visit_attributes)
    if visit_attributes
      ref_planning = row[:planning_ref].blank? ? nil : row[:planning_ref].downcase
      # Instersection of tags of all rows for tags of new planning
      if !@common_tags[ref_planning]
        @common_tags[ref_planning] = (visit_attributes[:tag_ids].to_a | destination_attributes[:tag_ids].to_a)
      else
        @common_tags[ref_planning] &= (visit_attributes[:tag_ids].to_a | destination_attributes[:tag_ids].to_a)
      end

      # Add visit to route if needed
      if row.key?(:route) && (visit_attributes[:id].nil? || !@visit_ids.include?(visit_attributes[:id]))
        ref_route = row[:route].blank? ? nil : row[:route].downcase # ref has to be nil for out-of-route
        if ref_route && row[:ref_vehicle]
          ref_vehicle = row[:ref_vehicle].gsub(%r{[\./\\]}, ' ').downcase
          if @plannings_routes[ref_planning][ref_route].key?(:ref_vehicle) &&
             @plannings_routes[ref_planning][ref_route][:ref_vehicle] != ref_vehicle ||
             @plannings_vehicles[ref_planning][ref_vehicle] &&
             @plannings_vehicles[ref_planning][ref_vehicle] != ref_route
            raise ImportInvalidRow.new(I18n.t('destinations.import_file.refs_route_discordant'))
          end
          @plannings_routes[ref_planning][ref_route][:ref_vehicle] = ref_vehicle
          @plannings_vehicles[ref_planning][ref_vehicle] = ref_route
        end
        @plannings_routes[ref_planning][ref_route][:visits] << [:visit, visit_attributes, ValueToBoolean.value_to_boolean(row[:active], true)]
        @visit_ids << visit_attributes[:id] if visit_attributes[:id]
      end
    end
  end

  def prepare_plannings(name, _options)
    # Generate new plannings
    @plannings_routes.each{ |ref, routes_hash|
      next if @provided_planning_attributes.empty? && ref.nil? && routes_hash.keys.compact.empty?

      planning = ref ? @plannings_hash[ref] : @plannings_hash[@provided_planning_attributes[:ref]&.downcase&.to_sym]
      unless planning
        attributes = @plannings_attributes[ref]
        planning = Planning.new(attributes)
      end
      planning.assign_attributes(@provided_planning_attributes)
      unless planning.name
        planning.assign_attributes({
          name: name || I18n.t('activerecord.models.planning') + ' ' + I18n.l(Time.zone.now, format: :long)
        })
      end
      planning.assign_attributes({tag_ids: (ref && @common_tags[ref] || @common_tags[nil] || [])})
      routes_hash.each{ |k, v|
        # Duplicated visit lines are only represented by a single visit
        v[:visits].select!{ |_type, attribute, _active|
          attribute[:id] ||
            @visit_index_to_id_hash[attribute[:visit_index]] ||
            @store_index_to_id_hash[attribute[:store_index]]
        }
        visit_ids = v[:visits].map{ |type, attribute, _active|
          next unless type == :visit

          attribute[:id] || @visit_index_to_id_hash[attribute[:visit_index]]
        }
        visits = Visit.includes_destinations_and_stores.where(id: visit_ids).index_by(&:id).values_at(*visit_ids)

        store_ids = v[:visits].map{ |type, attribute, _active|
          next unless type == :store

          attribute[:id] || @store_index_to_id_hash[attribute[:store_index]]
        }
        stores = Store.where(id: store_ids).index_by(&:id).values_at(*store_ids)

        v[:visits].map!.with_index{ |(_type, _attribute, active), index| [visits[index] || stores[index], active] }
      }
      if !(planning.id ? planning.update_routes(routes_hash, recompute = true) : planning.set_routes(routes_hash, false, true))
        raise ImportTooManyRoutes.new(I18n.t('errors.planning.import_too_many_routes')) if routes_hash.keys.size > planning.routes.size || routes_hash.keys.compact.size > @customer.max_vehicles
      end
      planning.split_by_zones(nil) if @provided_planning_attributes.key?(:zonings) || @provided_planning_attributes.key?(:zoning_ids)
      @plannings.push(planning)
    }

    # Add new visits to pre existing plannings
    (@customer.plannings - @plannings).each{ |planning|
      planning.visit_filling
    }
  end

  def import_errors_with_indices(slice_lines, slice_index, failed_instances)
    failed_instances.group_by{ |index_in_dataset, object_with_errors|
      object_with_errors.errors.messages.map{ |key, message|
        [columns.include?(key) ? columns[key][:title] : nil, message].compact.join(' ')
      }
    }.map{ |errors, grouped_failed_instances|
      failed_indices = grouped_failed_instances.flat_map{ |index, _object| slice_lines[index].map{ |slice_line| slice_index * 1000 + slice_line + 2 }} # index start at 0 + header
      I18n.t('import.data_erroneous.csv', s: failed_indices.join(',')) + ' - ' + errors.join(', ')
    }.join(';')
  end

  def custom_date_parse(date_string)
    parsed_date = Date.strptime(date_string, I18n.t('destinations.import_file.format.date'))
    return parsed_date if parsed_date.year > 100

    Date.strptime(date_string, I18n.t('destinations.import_file.format.date_short'))
  end
end
