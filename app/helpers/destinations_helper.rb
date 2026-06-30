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
module DestinationsHelper
  # Builds params hash for destinations index URL (search, filters, pagination).
  def destinations_index_params(overrides = {})
    base = { page: params[:page], per_page: params[:per_page], q: params[:q], filters: Array(params[:filters]).compact }
    base.merge(overrides)
  end

  # Placeholder example for search input (localized key names).
  def destinations_search_placeholder
    I18n.t(
      'destinations.index.search_placeholder',
      name_key: I18n.t('destinations.index.search_keys.name'),
      city_key: I18n.t('destinations.index.search_keys.city')
    )
  end

  # Search filter keys exposed in the filtered-search dropdown.
  def destinations_search_filter_options
    DestinationSearchParser::ALLOWED_KEYS.map do |key|
      {
        key: key,
        localized_key: I18n.t("destinations.index.search_keys.#{key}", default: key)
      }
    end
  end

  # Params for URL when removing a filter badge (excludes the given filter, resets to page 1).
  def destinations_index_params_without_filter(filter_to_remove)
    remaining = Array(params[:filters]).compact.reject { |f| f.to_s == filter_to_remove.to_s }
    destinations_index_params(filters: remaining, page: 1)
  end

  # Column ids available for the destinations index table (customer-dependent).
  def destinations_list_allowed_column_ids(customer)
    ::Preferences::Catalog.destinations_list_allowed_column_ids(customer)
  end

  # Active column ids for the destinations index (user preference, filtered by customer).
  def destinations_list_active_column_ids(customer)
    allowed = destinations_list_allowed_column_ids(customer)
    active =
      if user_signed_in? && current_user.respond_to?(:destinations_list_active_column_ids) && !current_user.admin?
        current_user.destinations_list_active_column_ids
      else
        ::Preferences::Catalog::DestinationsList.default_active_for(customer)
      end
    ::Preferences::Catalog.filter_order(active, allowed)
  end

  def destinations_list_columns_selector_options(customer)
    active_ids = destinations_list_active_column_ids(customer)
    destinations_list_allowed_column_ids(customer).map do |id|
      { id: id, label: destinations_list_column_label(id), active: active_ids.include?(id) }
    end
  end

  def destinations_list_column_label(column_id)
    I18n.t("display_ui.destinations_list_columns.#{column_id}", default: column_id.to_s.humanize)
  end

  def destinations_list_formatted_address(destination)
    [destination.street, destination.postalcode, destination.city, destination.country].compact.join(' ')
  end

  def destinations_list_phone_link(destination)
    return nil if destination.phone_number.blank?

    href =
      if current_user.url_click2call.present?
        current_user.link_phone_number.sub('{TEL}', destination.phone_number.to_s)
      else
        "tel:#{destination.phone_number}"
      end
    link_to destination.phone_number, href, class: 'text-nowrap'
  end

  def destinations_list_geocoding_level_title(destination)
    return nil if destination.geocoding_level.blank?

    "#{I18n.t('activerecord.attributes.destination.geocoding_level')} : #{I18n.t("destinations.form.geocoding_level.#{destination.geocoding_level}")}"
  end

  def destinations_list_geocoding_level_icon_class(destination)
    case destination.geocoding_level&.to_s
    when 'point' then 'fa-map-marker'
    when 'house' then 'fa-store'
    when 'street' then 'fa-road'
    when 'intersection' then 'fa-times'
    when 'city' then 'fa-exclamation-triangle'
    end
  end

  def destinations_list_geocoding_result_free(destination)
    result = destination.geocoding_result
    return nil unless result.is_a?(Hash)

    result['free'].presence
  end

  def destinations_list_geocoding_accuracy_percent(destination)
    return nil unless destination.geocoding_accuracy

    ((destination.geocoding_accuracy || 0) * 100).round
  end

  # Unique visit tags across all visits of the destination.
  def destinations_list_visit_tags(destination)
    destination.visits.flat_map(&:tags).uniq(&:id).sort_by(&:label)
  end

  # Unique visit category labels (tags) across all visits of the destination.
  def destinations_list_visit_tags_labels(destination)
    destinations_list_visit_tags(destination).map(&:label)
  end

  def csv_column_titles(customer, options = {})
    custom_columns = customer.advanced_options&.dig('import', 'destinations', 'spreadsheetColumnsDef')
    columns(customer, options).map{ |c|
      if custom_columns&.key?(c.to_s)
        custom_columns[c.to_s]
      elsif (m = m = /^(.+)\[(.*)\]$/.match(c))
        I18n.t('destinations.import_file.' + m[1]) + "[#{m[2]}]"
      elsif (m = /^([a-z]+(?:_[a-z]+)*)(\d+)$/.match(c))
        deliverable_unit = customer.deliverable_units.where(id: m[2].to_i).first
        I18n.t("destinations.import_file.#{m[1]}") + (deliverable_unit.label ? "[#{deliverable_unit.label}]" : "#{deliverable_unit.id}")
      else
        I18n.t('destinations.import_file.' + c.to_s)
      end
    }
  end

  def columns_destination(customer)
    dest_columns = %i[ref name street detail postalcode city]
    dest_columns << :state if customer.with_state?
    dest_columns += %i[country lat lng geocoding_accuracy geocoding_level geocoding_result comment phone_number tags destination_duration]

    dest_columns
  end

  def columns_visit(customer)
    visit_columns = %i[ref_visit duration time_window_start_1 time_window_end_1 time_window_start_2 time_window_end_2]
    visit_columns += %i[priority revenue tag_visits force_position]
    unless @customer.enable_orders
      customer.deliverable_units.each{ |du|
        visit_columns += ["pickup#{du.id}".to_sym, "delivery#{du.id}".to_sym]
      }
    end
    visit_columns += @customer.custom_attributes.for_visit.map{ |ca| "custom_attributes_visit[#{ca.name}]" }
    visit_columns
  end

  def columns(customer, options = {})
    total_columns = columns_destination(customer)
    total_columns += options[:extra_destination_columns] if options[:extra_destination_columns]&.is_a?(Array)
    total_columns << :without_visit
    total_columns += columns_visit(customer)
  end

  def csv_columns_content(destination, customer, options = {})
    csv = []
    destination_columns = [
      destination.ref,
      destination.name,
      destination.street,
      destination.detail,
      destination.postalcode,
      destination.city
    ] + (customer.with_state? ? [destination.state] : []) + [
      destination.country,
      destination.lat&.round(6),
      destination.lng&.round(6),
      destination.geocoding_accuracy,
      destination.geocoding_level,
      destination.geocoding_result.dig('free'),
      destination.comment,
      destination.phone_number,
      destination.tags.collect(&:label).join(','),
      destination.duration_absolute_time_with_seconds
    ]
    if options[:extra_destination_columns]&.is_a?(Array)
      options[:extra_destination_columns].each{ |extra_col|
        if extra_col.is_a?(Array)
          destination_columns << extra_col.join(',')
        else
          destination_columns << extra_col
        end
      }
    end
    if destination.visits.size > 0
      destination.visits.each { |visit|
        csv << destination_columns + [
          '',
          visit.ref,
          visit.duration_absolute_time_with_seconds,
          visit.time_window_start_1_absolute_time,
          visit.time_window_end_1_absolute_time,
          visit.time_window_start_2_absolute_time,
          visit.time_window_end_2_absolute_time,
          visit.priority,
          visit.revenue,
          visit.tags.collect(&:label).join(','),
          I18n.t("activerecord.models.visits.force_position.#{visit.force_position}")
        ] + (customer.enable_orders ?
          [] :
          customer.deliverable_units.flat_map{ |du|
            [
              visit.pickups[du.id],
              visit.deliveries[du.id]
            ]
          }) +
          customer.custom_attributes.for_visit.map{ |ca|
            visit.custom_attributes_typed_hash[ca.name]
          }
      }
    else
      csv << destination_columns + ['x']
    end
    csv
  end
end
