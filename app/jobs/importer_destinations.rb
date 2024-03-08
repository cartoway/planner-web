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
  attr_accessor :plannings

  def initialize(customer, planning_hash = nil)
    super customer
    @planning_hash = planning_hash || {}
  end

  def max_lines
    @customer.default_max_destinations
  end

  def columns_planning
    {
      planning_ref: {title: I18n.t('destinations.import_file.planning_ref'), desc: I18n.t('destinations.import_file.planning_ref_desc'), format: I18n.t('destinations.import_file.format.string')},
      planning_name: {title: I18n.t('destinations.import_file.planning_name'), desc: I18n.t('destinations.import_file.planning_name_desc'), format: I18n.t('destinations.import_file.format.string')},
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
    columns_destination =
    {
      ref: {title: I18n.t('destinations.import_file.ref'), desc: I18n.t('destinations.import_file.ref_desc'), format: I18n.t('destinations.import_file.format.string')},
      name: {title: I18n.t('destinations.import_file.name'), desc: I18n.t('destinations.import_file.name_desc'), format: I18n.t('destinations.import_file.format.string'), required: I18n.t('destinations.import_file.format.required')},
      street: {title: I18n.t('destinations.import_file.street'), desc: I18n.t('destinations.import_file.street_desc'), format: I18n.t('destinations.import_file.format.string'), required: I18n.t('destinations.import_file.format.advisable')},
      detail: {title: I18n.t('destinations.import_file.detail'), desc: I18n.t('destinations.import_file.detail_desc'), format: I18n.t('destinations.import_file.format.string')},
      postalcode: {title: I18n.t('destinations.import_file.postalcode'), desc: I18n.t('destinations.import_file.postalcode_desc'), format: I18n.t('destinations.import_file.format.integer'), required: I18n.t('destinations.import_file.format.advisable')},
      city: {title: I18n.t('destinations.import_file.city'), desc: I18n.t('destinations.import_file.city_desc'), format: I18n.t('destinations.import_file.format.string'), required: I18n.t('destinations.import_file.format.advisable')}
    }

    columns_destination.merge!(state: {title: I18n.t('destinations.import_file.state'), desc: I18n.t('destinations.import_file.state_desc'), format: I18n.t('destinations.import_file.format.string'), required: I18n.t('destinations.import_file.format.advisable')}) if @customer.with_state?

    columns_destination.merge!({
      country: {title: I18n.t('destinations.import_file.country'), desc: I18n.t('destinations.import_file.country_desc'), format: I18n.t('destinations.import_file.format.string')},
      lat: {title: I18n.t('destinations.import_file.lat'), desc: I18n.t('destinations.import_file.lat_desc'), format: I18n.t('destinations.import_file.format.float')},
      lng: {title: I18n.t('destinations.import_file.lng'), desc: I18n.t('destinations.import_file.lng_desc'), format: I18n.t('destinations.import_file.format.float')},
      phone_number: {title: I18n.t('destinations.import_file.phone_number'), desc: I18n.t('destinations.import_file.phone_number_desc'), format: I18n.t('destinations.import_file.format.integer')},
      comment: {title: I18n.t('destinations.import_file.comment'), desc: I18n.t('destinations.import_file.comment_desc'), format: I18n.t('destinations.import_file.format.string')},
      tags: {title: I18n.t('destinations.import_file.tags'), desc: I18n.t('destinations.import_file.tags_desc'), format: I18n.t('destinations.import_file.tags_format')}
    })

    columns_destination
  end

  def columns_visit
    {
      ref_visit: {title: I18n.t('destinations.import_file.ref_visit'), desc: I18n.t('destinations.import_file.ref_visit_desc'), format: I18n.t('destinations.import_file.format.string')},
      time_window_start_1: {title: I18n.t('destinations.import_file.time_window_start_1'), desc: I18n.t('destinations.import_file.time_window_start_1_desc'), format: I18n.t('destinations.import_file.format.hour')},
      time_window_end_1: {title: I18n.t('destinations.import_file.time_window_end_1'), desc: I18n.t('destinations.import_file.time_window_end_1_desc'), format: I18n.t('destinations.import_file.format.hour')},
      time_window_start_2: {title: I18n.t('destinations.import_file.time_window_start_2'), desc: I18n.t('destinations.import_file.time_window_start_2_desc'), format: I18n.t('destinations.import_file.format.hour')},
      time_window_end_2: {title: I18n.t('destinations.import_file.time_window_end_2'), desc: I18n.t('destinations.import_file.time_window_end_2_desc'), format: I18n.t('destinations.import_file.format.hour')},
      priority: {title: I18n.t('destinations.import_file.priority'), desc: I18n.t('destinations.import_file.priority_desc'), format: I18n.t('destinations.import_file.format.integer')},
      force_position: {title: I18n.t('destinations.import_file.force_position'), desc: I18n.t('destinations.import_file.force_position_desc'), format: I18n.t('destinations.import_file.force_position_format')},
      tags_visit: {title: I18n.t('destinations.import_file.tags_visit'), desc: I18n.t('destinations.import_file.tags_visit_desc'), format: I18n.t('destinations.import_file.tags_format')},
      duration: {title: I18n.t('destinations.import_file.duration'), desc: I18n.t('destinations.import_file.duration_desc'), format: I18n.t('destinations.import_file.format.hour')},
    }.merge(Hash[@customer.deliverable_units.flat_map{ |du|
      [["quantity#{du.id}".to_sym, {title: I18n.t('destinations.import_file.quantity') + (du.label ? "[#{du.label}]" : "#{du.id}"), desc: I18n.t('destinations.import_file.quantity_desc'), format: I18n.t('destinations.import_file.format.float')}],
      ["quantity_operation#{du.id}".to_sym, {title: I18n.t('destinations.import_file.quantity_operation') + (du.label ? "[#{du.label}]" : "#{du.id}"), desc: I18n.t('destinations.import_file.quantity_operation_desc'), format: I18n.t('destinations.import_file.quantity_operation_format')}]]
    }]).merge(Hash[@customer.custom_attributes.select(&:visit?).map { |ca|
    ["custom_attributes_visit[#{ca.name}]", { title: "#{I18n.t('destinations.import_file.custom_attributes_visit')}[#{ca.name}]", format: I18n.t("destinations.import_file.format.#{ca.object_type}")}]
  }])
  end

  def columns
    columns_planning.merge(columns_route).merge(columns_destination).merge(columns_visit).merge(
      without_visit: {title: I18n.t('destinations.import_file.without_visit'), desc: I18n.t('destinations.import_file.without_visit_desc'), format: I18n.t('destinations.import_file.format.yes_no')},
      quantities: {}, # only for json import
      quantities_operations: {}, # only for json import
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
          v[:tags_visit] = v[:tag_ids].collect(&:to_i) if !v.key?(:tags) && v.key?(:tag_ids)
          v[:quantities] = Hash[v[:quantities].map{ |q| [q[:deliverable_unit_id], q[:quantity]] }] if v[:quantities] && v[:quantities].is_a?(Array)
          dest.except(:visits).merge(v)
        }
      else
        [dest.merge(without_visit: 'x')]
      end
    }.flatten
  end

  def rows_to_json(rows)
    dest_ids = rows.collect(&:id).uniq
    @customer.destinations.select{ |d|
      dest_ids.include?(d.id)
    }
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
    @plannings_hash = Hash[@customer.plannings.select(&:ref).map{ |plan| [plan.ref, plan] }]
    @destinations_to_geocode = []
    @visit_ids = []

    if options[:delete_plannings]
      @customer.plannings.delete_all
    end
    if options[:replace]
      @customer.delete_all_destinations
    end
    if options[:line_shift] == 1
      # Create missing deliverable units if needed
      column_titles = data[0].is_a?(Hash) ? data[0].keys : data.size > 0 ? data[0].map{ |a| a[0] } : []
      unit_labels = @customer.deliverable_units.map(&:label)
      column_titles.each{ |name|
        m = Regexp.new("^" + I18n.t('destinations.import_file.quantity') + "\\[(.*)\\]$").match(name)
        if m && unit_labels.exclude?(m[1])
          unit_labels.delete_at(unit_labels.index(m[1])) if unit_labels.index(m[1])
          @customer.deliverable_units.build(label: m[1])
        end
      }
      @customer.save!
    end

    @destinations_by_ref = Hash[@customer.destinations.select(&:ref).collect{ |destination| [destination.ref, destination] }]
    # @visits_by_ref must contains ref with and without destination since destination ref could not be present in imported data
    @visits_by_ref = Hash[@customer.destinations.flat_map(&:visits).select(&:ref).flat_map{ |visit| [["#{visit.destination.ref}/#{visit.ref}", visit], ["/#{visit.ref}", visit]] }.uniq]
    @destinations_visits_by_ref = Hash[@customer.destinations.select(&:ref).map{ |destination| [destination.ref, Hash.new] }]
    @destinations_visits_by_ref[nil] = Hash.new
    @customer.destinations.select(&:ref).flat_map(&:visits).each{ |visit| @destinations_visits_by_ref[visit.destination.ref][visit.ref] = visit }
    # @plannings_by_ref set in import_row in order to have internal row title
    @plannings_by_ref = {}
    @@col_dest_keys ||= columns_destination.keys
    @col_visit_keys = columns_visit.keys + [:quantities, :quantities_operations, :custom_attributes_visit]
    @@slice_attr ||= (@@col_dest_keys - [:customer_id, :lat, :lng]).collect(&:to_s)
    @destinations_by_attributes = Hash[@customer.destinations.collect{ |destination| [destination.attributes.slice(*@@slice_attr), destination] }]

    @destinations = []
    @visits = []
    @plannings = []
    @plannings_attributes = {}
  end

  def uniq_ref(row)
    row[:stop_type] = row[:stop_type].present? ? valid_stop_type(row[:stop_type]) : I18n.t('destinations.import_file.stop_type_visit')
    return if row.key?(:stop_type) && row[:stop_type] != I18n.t('destinations.import_file.stop_type_visit')
    row[:ref] || row[:ref_visit] ? [row[:ref], row[:ref_visit]] : nil
  end

  def prepare_quantities(row)
    q = {}
    qo = {}
    row.each{ |key, value|
      /^quantity([0-9]+)$/.match(key.to_s) { |m|
        q.merge! Integer(m[1]) => row.delete(m[0].to_sym)
      }
      /^quantity_operation([0-9]+)$/.match(key.to_s) { |m|
        o = row.delete(m[0].to_sym)
        o = o == I18n.t('destinations.import_file.quantity_operation_fill') ? 'fill' : o == I18n.t('destinations.import_file.quantity_operation_empty') ? 'empty' : nil
        qo.merge! Integer(m[1]) => o
      }
    }
    row[:quantities] = q unless q.empty?
    row[:quantities_operations] = qo unless qo.empty?

    # Deals with deprecated quantity
    if !row.key?(:quantities)
      if row.key?(:quantity) && @customer.deliverable_units.size > 0
        row[:quantities] = {@customer.deliverable_units[0].id => row.delete(:quantity)}
      elsif (row.key?(:quantity1_1) || row.key?(:quantity1_2)) && @customer.deliverable_units.size > 0
        row[:quantities] = {}
        row[:quantities].merge!({@customer.deliverable_units[0].id => row.delete(:quantity1_1)}) if row.key?(:quantity1_1)
        row[:quantities].merge!({@customer.deliverable_units[1].id => row.delete(:quantity1_2)}) if row.key?(:quantity1_2) && @customer.deliverable_units.size > 1
      end
    end
  end

  def prepare_tags(row, key)
    if !row[key].nil?
      if row[key].is_a?(String)
        row[key] = row[key].split(',').uniq.select{ |key|
          !key.empty?
        }
      end

      row[key] = row[key].collect{ |tag|
        if tag.is_a?(Integer)
          @tag_ids[tag]
        else
          tag = tag.strip
          if !@tag_labels.key?(tag)
            @tag_labels[tag] = @customer.tags.build(label: tag)
          end
          @tag_labels[tag]
        end
      }.compact
    elsif row.key?(key)
      row.delete key
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
    %w(always_first never_first neutral always_final).each do |t|
      type ||= t if force_position == I18n.t("activerecord.models.visits.force_position.#{t}")
    end
    type || :neutral
  end

  def is_visit?(type)
    type == I18n.t('destinations.import_file.stop_type_visit')
  end

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

  def build_attributes(row)
    @plannings_attributes[row[:planning_ref]] ||=
      {
        ref: row[:planning_ref],
        name: row[:planning_name],
        customer: @customer,
        vehicle_usage_set: @customer.vehicle_usage_sets[0]
      }

    destination_attributes = row.slice(*@@col_dest_keys)
    visit_attributes = row.slice(*@col_visit_keys)
    visit_attributes[:ref] = visit_attributes.delete :ref_visit
    visit_attributes[:tags] = visit_attributes.delete :tags_visit if visit_attributes.key?(:tags_visit)
    visit_attributes[:custom_attributes] = visit_attributes.delete :custom_attributes_visit if visit_attributes.key?(:custom_attributes_visit)
    visit_attributes[:force_position] = row[:force_position].present? && convert_force_position(row[:force_position])

    [destination_attributes, visit_attributes]
  end

  def prepare_destination(row, destination_attributes, visit_attributes)
    destination, visit = nil
    if row[:ref].present? && !row[:ref].strip.empty?
      destination = @destinations_by_ref[row[:ref]]
      if destination
        lat_lng_attributes = (destination_attributes.key?(:lat) || destination_attributes.key?(:lng)) ? {lat: nil, lng: nil} : {}
        # Compact allows to avoid erasing nil fields
        destination.assign_attributes(lat_lng_attributes.merge(destination_attributes.compact))
      else
        destination = @customer.destinations.new(destination_attributes)
        @destinations_by_ref[destination.ref] = destination if destination.ref
        @destinations_by_attributes[destination.attributes.slice(*@@slice_attr)] = destination
        @destinations_visits_by_ref[destination.ref] = Hash.new
      end
      visit = prepare_visit_with_destination(row, destination, visit_attributes)
    else
      destination, visit = prepare_visit_without_destination_ref(row, destination_attributes, visit_attributes)
    end
    [destination, visit]
  end

  def prepare_visit_with_destination(row, destination, visit_attributes)
    visit = nil
    if row[:without_visit].nil? || row[:without_visit].strip.empty?
      visit = @destinations_visits_by_ref[destination.ref][row[:ref_visit]]
      if visit
        # Compact allows to avoid erasing nil fields
        visit.assign_attributes(visit_attributes.compact)
      else
        visit = destination.visits.new(visit_attributes)
        @destinations_visits_by_ref[visit.destination.ref][visit.ref] = visit
      end
    else
      destination.visits.destroy_all
    end
    visit
  end

  def prepare_visit_without_destination_ref(row, destination_attributes, visit_attributes)
    if row[:ref_visit].present? && !row[:ref_visit].strip.empty?
      visit = @destinations_visits_by_ref[nil][row[:ref_visit]]
      if visit
        visit.destination.assign_attributes(destination_attributes)
        visit.assign_attributes(visit_attributes)
      end
    end

    if !visit
      destination =
        if @customer.enable_multi_visits
          row_compare_attr = (@@dest_attr_nil ||= Hash[*columns_destination.keys.collect{ |v| [v, nil] }.flatten]).merge(destination_attributes).except(:lat, :lng, :tags).stringify_keys
          @destinations_by_attributes[row_compare_attr]
        end
      if destination
        destination.assign_attributes(destination_attributes)
      else
        destination = @customer.destinations.new(destination_attributes)
        # No destination.ref here for @destinations_by_ref
        @destinations_by_attributes[destination.attributes.slice(*@@slice_attr)] = destination
      end
      if row[:without_visit].nil? || row[:without_visit].strip.empty?
        # Link only when destination is complete
        visit = destination.visits.new(visit_attributes)
        @destinations_visits_by_ref[visit.destination.ref][visit.ref] = visit if visit.ref
      end
    end
    [destination, visit]
  end

  def prepare_destination_in_planning(row, destination, visit)
    if visit
      # Instersection of tags of all rows for tags of new planning
      if !@common_tags[row[:planning_ref]]
        @common_tags[row[:planning_ref]] = (visit.tags.to_a | visit.destination.tags.to_a)
      else
        @common_tags[row[:planning_ref]] &= (visit.tags | visit.destination.tags)
      end

      visit.destination.delay_geocode
      if need_geocode? visit.destination
        @destinations_to_geocode << visit.destination
        visit.destination.lat = nil # for job
      end

      # Add visit to route if needed
      if row.key?(:route) && (visit.id.nil? || !@visit_ids.include?(visit.id))
        ref_planning = row[:planning_ref].blank? ? nil : row[:planning_ref]
        ref_route = row[:route].blank? ? nil : row[:route] # ref has to be nil for out-of-route
        @plannings_routes[ref_planning][ref_route][:ref_vehicle] = row[:ref_vehicle].gsub(%r{[\./\\]}, ' ') if row[:ref_vehicle]
        @plannings_routes[ref_planning][ref_route][:visits] << [visit, ValueToBoolean.value_to_boolean(row[:active], true)]
        @visit_ids << visit.id if visit.id
      end
      visit.destination # For subclasses
    else
      destination.delay_geocode
      if need_geocode? destination
        @destinations_to_geocode << destination
        destination.lat = nil # for job
      end
    end
  end

  def import_row(_name, row, _options)
    return unless is_visit?(row[:stop_type])

    destination = nil
    visit = nil

    convert_deprecated_fields(row)
    prepare_quantities(row)
    prepare_custom_attributes(row)
    [:tags, :tags_visit].each{ |key| prepare_tags row, key }

    destination_attributes, visit_attributes = build_attributes(row)

    destination, visit = prepare_destination(row, destination_attributes, visit_attributes)

    valid_row visit ? visit.destination : destination

    prepare_destination_in_planning(row, destination, visit)
    @destinations << destination
    destination
  end

  def prepare_plannings(name, _options)
    @plannings_routes.each{ |ref, routes_hash|
      planning = @plannings_hash[ref] if ref
      unless planning
        attributes = @plannings_attributes[ref]
        planning = Planning.new(attributes)
      end
      planning.assign_attributes({
        name: name || I18n.t('activerecord.models.planning') + ' ' + I18n.l(Time.zone.now, format: :long)
      }.merge(@planning_hash))
      planning.assign_attributes({tags: (ref && @common_tags[ref] || @common_tags[nil] || [])})
      unless planning.set_routes routes_hash, false, true
        raise ImportTooManyRoutes.new(I18n.t('errors.planning.import_too_many_routes')) if routes_hash.keys.size > planning.routes.size || routes_hash.keys.compact.size > @customer.max_vehicles
      end
      planning.split_by_zones(nil) if @planning_hash.key?(:zonings) || @planning_hash.key?(:zoning_ids)
      @plannings.push(planning)
    }
  end

  def after_import(name, _options)
    if !@destinations_to_geocode.empty? && (@synchronous || !Mapotempo::Application.config.delayed_job_use)
      @destinations_to_geocode.each_slice(50){ |destinations|
        geocode_args = destinations.collect(&:geocode_args)
        begin
          results = Mapotempo::Application.config.geocoder.code_bulk(geocode_args)
          destinations.zip(results).each { |destination, result|
            destination.geocode_result(result) if result
          }
        rescue GeocodeError # avoid stop import because of geocoding job
        end
      }
    end

    @customer.save!
    @destinations.uniq!
    # activerecord-import cannot update recursive existing visits
    existing_destinations = @destinations.select{ |dest| dest.id.present? }
    Destination.import(@destinations - existing_destinations, on_duplicate_key_update: { conflict_target: [:id], columns: :all }, recursive: true)
    related_visits = existing_destinations.flat_map(&:visits)
    Visit.import(related_visits, on_duplicate_key_update: { conflict_target: [:id], columns: :all })

    prepare_plannings(name, _options)
  end

  def save_plannings
    @plannings.each { |planning|
      if !planning.id
        planning.save_import!
      else
        planning.save!
      end
    }
  end

  def finalize_import(_name, _options)
    if !@destinations_to_geocode.empty? && !@synchronous && Mapotempo::Application.config.delayed_job_use
      save_plannings
      @customer.job_destination_geocoding = Delayed::Job.enqueue(GeocoderDestinationsJob.new(@customer.id, !@plannings.empty? ? @plannings.map(&:id) : nil))
    elsif !@plannings.empty?
      @plannings.each{ |planning|
        planning.compute(ignore_errors: true)
      }
      save_plannings
    end

    @customer.save!
  end
end
