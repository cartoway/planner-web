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
require 'value_to_boolean'
require 'exceptions'

module ApplicationHelper
  include Pagy::Frontend
  include PreferencesHelper

  def javascript(*files)
    files.each do |file|
      content_for(:javascript) { javascript_pack_tag(file, **{'data-turbolinks-track': 'reload'}) }
    end
  end

  def span_tag(content)
    content_tag :span, content, class: 'default-color'
  end

  def number_to_human(number, options = {})
    options.merge! delimiter: I18n.t('number.format.delimiter'), separator: I18n.t('number.format.separator'), strip_insignificant_zeros: true
    super number, options
  end

  def customised_color_verification(data)
    if data.nil?
      DEFAULT_COLOR
    elsif COLORS_TABLE.include? data
      DEFAULT_COLOR
    else
      data
    end
  end

  def locale_distance(distance, unit = 'km', options = {})
    base_options = { units: :distance, precision: 3, format: '%n %u' }
    options.merge!(base_options)

    if !unit.nil? && unit != 'km'
      distance = distance / 1.609344
      options[:units] = :distance_miles
    end

    if !options[:display_unit].nil? && !options[:display_unit]
      options.except!(:units)
    end

    number_to_human(distance, options)
  end

  def number_of_days(time_in_seconds)
    if time_in_seconds && time_in_seconds > 0
      number_of_days = (time_in_seconds / 86400).to_i
      number_of_days > 0 ? number_of_days : nil
    end
  end

  def to_bool(str)
    ValueToBoolean.value_to_boolean str
  end

  def nested_has_error?(key, id)
    manager = Exceptions::NestedAttributesManager.instance
    error_list = manager.get_hash_for(key, id)
    'has-error nested' if error_list
  end

  def analytic_url_for(klass, type)
    url = klass.is_a?(Customer) ? klass.reseller.send(type.to_sym) : klass.send(type.to_sym)
    return if !url

    url.gsub('{ID}', klass.id.to_s)
  end

  def time_over_day(time_in_seconds)
    '%02i:%02i' % [time_in_seconds / 3600, (time_in_seconds % 3600) / 60]
  end

  def round_time_to_nearest_quarter(time)
    minutes = (time.min + time.sec / 60.0)
    rounded = (minutes / 15.0).round * 15
    time.beginning_of_hour + rounded.minutes
  end

  def confirm_click_data(group:, wait_message:, confirm_message:, base_class:, ready_label: nil)
    {
      controller: 'confirm-click',
      confirm_click_group_value: group,
      confirm_click_wait_message_value: wait_message,
      confirm_click_confirm_message_value: confirm_message,
      confirm_click_base_class_value: base_class
    }.tap do |data|
      data[:confirm_click_ready_label_value] = ready_label if ready_label.present?
    end
  end

  # StopVisit JSON: tags_present = destination tags, visit_tags_present = visit tags.
  def visit_stop_tags_present_json!(json, visit)
    dest = visit.destination.tags
    vis = visit.tags

    if dest.any?
      json.tags_present do
        json.tags do
          json.array! dest, :label
        end
      end
    end

    if vis.any?
      json.visit_tags_present do
        json.tags do
          json.array! vis, :label
        end
      end
    end
  end
end
