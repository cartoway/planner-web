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
      tags_visit: {title: I18n.t('destinations.import_file.tags_visit'), desc: I18n.t('destinations.import_file.tags_visit_desc'), format: I18n.t('destinations.import_file.tags_format')},
      duration: {title: I18n.t('destinations.import_file.duration'), desc: I18n.t('destinations.import_file.duration_desc'), format: I18n.t('destinations.import_file.format.hour')},
    }.merge(Hash[@customer.deliverable_units.flat_map{ |du|
      [["quantity#{du.id}".to_sym, {title: I18n.t('destinations.import_file.quantity') + (du.label ? '[' + du.label + ']' : ''), desc: I18n.t('destinations.import_file.quantity_desc'), format: I18n.t('destinations.import_file.format.float')}],
      ["quantity_operation#{du.id}".to_sym, {title: I18n.t('destinations.import_file.quantity_operation') + (du.label ? '[' + du.label + ']' : ''), desc: I18n.t('destinations.import_file.quantity_operation_desc'), format: I18n.t('destinations.import_file.quantity_operation_format')}]]
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
    @routes = Hash.new{ |h, k|
      h[k] = Hash.new{ |hh, kk|
        hh[kk] = kk == :visits ? [] : nil
      }
    }
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
    # @plannings_by_ref set in import_row in order to have internal row title
    @plannings_by_ref = nil
    @@col_dest_keys ||= columns_destination.keys
    @col_visit_keys = columns_visit.keys + [:quantities, :quantities_operations]
    @@slice_attr ||= (@@col_dest_keys - [:customer_id, :lat, :lng]).collect(&:to_s)
    @destinations_by_attributes = Hash[@customer.destinations.collect{ |destination| [destination.attributes.slice(*@@slice_attr), destination] }]
    @plannings = []
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

  def is_visit?(type)
    type == I18n.t('destinations.import_file.stop_type_visit')
  end

  def import_row(_name, row, _options)
    return unless is_visit?(row[:stop_type])

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

    prepare_quantities row
    [:tags, :tags_visit].each{ |key| prepare_tags row, key }

    if row[:planning_ref]
      @plannings_by_ref = Hash[@customer.plannings.map{ |p| [p.ref, p] }] unless @plannings_by_ref
      unless @plannings_by_ref.key? row[:planning_ref]
        # Do not link the planning to has_many of the customer, to avoid cascading while saving from customer.
        # The following save_import does not re-synchr the object in memory from database, unless explicitly requested.
        planning = Planning.new
        planning.assign_attributes({
          ref: row[:planning_ref],
          name: row[:planning_name],
          customer: @customer,
          vehicle_usage_set: @customer.vehicle_usage_sets[0]})
        planning.default_empty_routes
        @plannings_by_ref[row[:planning_ref]] = planning
        raise(Exceptions::OverMaxLimitError.new(I18n.t('activerecord.errors.models.customer.attributes.plannings.over_max_limit'))) if @customer.default_max_plannings && @plannings_by_ref.size > @customer.default_max_plannings
      end
      @plannings.push(@plannings_by_ref[row[:planning_ref]]) unless @plannings.include? @plannings_by_ref[row[:planning_ref]]
    end

    destination_attributes = row.slice(*@@col_dest_keys)
    visit_attributes = row.slice(*@col_visit_keys)
    visit_attributes[:ref] = visit_attributes.delete :ref_visit
    visit_attributes[:tags] = visit_attributes.delete :tags_visit if visit_attributes.key?(:tags_visit)

    if !row[:ref].nil? && !row[:ref].strip.empty?
      destination = @destinations_by_ref[row[:ref]]
      if destination
        destination.assign_attributes((destination_attributes.key?(:lat) || destination_attributes.key?(:lng) ?
          {lat: nil, lng: nil} :
          {}).merge(destination_attributes.compact)) # FIXME: don't use compact to overwrite database with row containing nil
      else
        destination = @customer.destinations.build(destination_attributes)
        @destinations_by_ref[destination.ref] = destination if destination.ref
        @destinations_by_attributes[destination.attributes.slice(*@@slice_attr)] = destination
      end
      if row[:without_visit].nil? || row[:without_visit].strip.empty?
        visit = if !row[:ref_visit].nil? && !row[:ref_visit].strip.empty?
          @visits_by_ref["#{destination.ref}/#{row[:ref_visit]}"]
        else
          # Get the first visit without ref
          destination.visits.find{ |v| !v.ref }
        end
        if visit
          visit.assign_attributes(visit_attributes.compact) # FIXME: don't use compact to overwrite database with row containing nil
        else
          visit = destination.visits.build(visit_attributes)
          @visits_by_ref["#{visit.destination.ref}/#{visit.ref}"] = visit if visit.ref
        end
      else
        destination.visits.destroy_all
      end
    else
      if !row[:ref_visit].nil? && !row[:ref_visit].strip.empty?
        visit = @visits_by_ref["#{row[:ref]}/#{row[:ref_visit]}"]
        if visit
          visit.destination.assign_attributes(destination_attributes)
          visit.assign_attributes(visit_attributes)
        end
      end
      if !visit
        # Get destination from attributes for multiple visits
        destination = if @customer.enable_multi_visits
            row_compare_attr = (@@dest_attr_nil ||= Hash[*columns_destination.keys.collect{ |v| [v, nil] }.flatten]).merge(destination_attributes).except(:lat, :lng, :tags).stringify_keys
            @destinations_by_attributes[row_compare_attr]
          else
            nil
          end
        if destination
          destination.assign_attributes(destination_attributes)
        else
          destination = @customer.destinations.build(destination_attributes)
          # No destination.ref here for @destinations_by_ref
          @destinations_by_attributes[destination.attributes.slice(*@@slice_attr)] = destination
        end
        if row[:without_visit].nil? || row[:without_visit].strip.empty?
          # Link only when destination is complete
          visit = destination.visits.build(visit_attributes)
          @visits_by_ref["#{visit.destination.ref}/#{visit.ref}"] = visit if visit.ref
        end
      end
    end

    valid_row visit ? visit.destination : destination
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
      visit.destination.validate! # to get errors first
      visit.save!

      # Add visit to route if needed
      if row.key?(:route) && !@visit_ids.include?(visit.id)
        ref_route = row[:route].blank? ? nil : row[:route] # ref has to be nil for out-of-route
        @routes[ref_route][:ref_vehicle] = row[:ref_vehicle].gsub(%r{[\./\\]}, ' ') if row[:ref_vehicle]
        @routes[ref_route][:visits] << [visit, ValueToBoolean.value_to_boolean(row[:active], true)]
        @visit_ids << visit.id
      end
      visit.destination # For subclasses
    else
      destination.delay_geocode
      if need_geocode? destination
        @destinations_to_geocode << destination
        destination.lat = nil # for job
      end
      destination.save!
      destination # For subclasses
    end
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

    unless @routes.keys.compact.empty? && @planning_hash.values.all?(&:blank?) || @plannings_by_ref
      planning = @customer.plannings.find{ |p| p.ref == @planning_hash['ref'] } if !@planning_hash['ref'].blank?
      unless planning
        # Do not link the planning to has_many of the customer, to avoid cascading while saving from customer.
        # The following save_import does not re-synchr the object in memory from database, unless explicitly requested.
        planning = Planning.new
        planning.assign_attributes({
          customer: @customer,
          vehicle_usage_set: @planning_hash[:vehicle_usage_set_id] && @customer.vehicle_usage_sets.find{ |vu| vu.id == @planning_hash[:vehicle_usage_set_id] } || @customer.vehicle_usage_sets[0]})
        planning.default_empty_routes
      end
      planning.assign_attributes({
        name: name || I18n.t('activerecord.models.planning') + ' ' + I18n.l(Time.zone.now, format: :long)
      }.merge(@planning_hash))
      @plannings.push(planning)
    end

    @plannings.each{ |planning|
      planning.assign_attributes({tags: (@common_tags[planning.ref] || @common_tags[nil] || [])})
      unless planning.set_routes @routes, false, true
        raise ImportTooManyRoutes.new(I18n.t('errors.planning.import_too_many_routes')) if @routes.keys.size > planning.routes.size || @routes.keys.compact.size > @customer.max_vehicles
      end
      planning.split_by_zones(nil) if @planning_hash.key?(:zonings) || @planning_hash.key?(:zoning_ids)
    }
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
