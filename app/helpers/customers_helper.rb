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
module CustomersHelper
  # Customer and reseller router selects only expose the time (fastest) dimension.
  ROUTER_SELECT_DIMENSION = 'time'.freeze

  def customer_plannings_count(customer)
    capture do
      concat '<span style="color: red; font-weight: bold;">'.html_safe if Rails.configuration.max_plannings_default && Rails.configuration.max_plannings_default <= customer.plannings_count
      concat customer.plannings_count
      concat '</span>'.html_safe if Rails.configuration.max_plannings_default && Rails.configuration.max_plannings_default <= customer.plannings_count
    end
  end

  def has_vehicle_with_unauthorized_router(customer)
    return false if customer.new_record? || customer.profile.blank? || customer.vehicles.where.not(router_id: nil).empty?
    (customer.vehicles.pluck(:router_id) - customer.profile.routers.pluck(:id)).present?
  end

  def has_user_with_unauthorized_layer(customer)
    return false if customer.new_record? || customer.profile.blank?
    (customer.users.pluck(:layer_id) - customer.profile.layers.pluck(:id)).present?
  end

  def customer_external_callback_name(customer, default)
    trad = customer.reseller[:external_callback_url_name] ? customer.reseller[:external_callback_url_name] : default
    t('web.form.default', n: trad)
  end

  def customer_external_callback_url(customer)
    customer.reseller[:external_callback_url] ? t('web.form.default', n: customer.reseller[:external_callback_url]) : ''
  end

  def deliverable_unit_icons(customer)
    customer.deliverable_units.map{ |du|
      [du.id, du.default_icon]
    }.to_h
  end

  def reseller_default_profile_router_combined_value(reseller)
    return nil if reseller.blank? || reseller.default_profile_id.blank? || reseller.default_router_id.blank?

    "#{reseller.default_profile_id}_#{reseller.default_router_id}_#{reseller.default_router_dimension}"
  end

  def import_user_role_options_for_select(reseller)
    reseller.roles.order(:name).map do |role|
      label = role.name
      if role.id == reseller.default_role_id
        label = t('customers.form.field_default', n: role.name)
      end
      [label, role.id]
    end
  end

  def customer_router_select_options(customer, admin:, reseller: nil)
    reseller ||= customer.reseller
    if admin
      profile_router_grouped_options_for_admin(customer, reseller: reseller)
    else
      router_options_for_dimension(Router.all, ROUTER_SELECT_DIMENSION, reseller: reseller)
    end
  end

  def customer_router_selected_value(customer, admin:)
    return nil if customer.router_id.blank?

    if admin && customer.profile_id.present?
      "#{customer.profile_id}_#{customer.router_id}_#{customer.router_dimension}"
    else
      "#{customer.router_id}_#{customer.router_dimension}"
    end
  end

  def profile_router_grouped_options_for_admin(_customer, reseller: nil)
    Profile.includes(:routers).map do |profile|
      [profile.name, profile_router_options(profile, reseller: reseller)]
    end
  end

  private

  def profile_router_options(profile, reseller: nil)
    profile.routers.flat_map do |router|
      router_options_for_router(router, profile.id, reseller: reseller)
    end
  end

  def router_options_for_dimension(routers, dimension, reseller: nil)
    routers.select { |router| router.public_send("#{dimension}?") }.map do |router|
      router_option_entry(router, dimension, nil, reseller)
    end
  end

  def router_options_for_router(router, profile_id, reseller: nil)
    return [] unless router.time?

    [router_option_entry(router, ROUTER_SELECT_DIMENSION, profile_id, reseller)]
  end

  def router_option_entry(router, dimension, profile_id, reseller)
    label = router_option_label(router, dimension)
    value = router_option_value(router, dimension, profile_id)
    html_options = {}
    if router_option_is_reseller_default?(router, dimension, profile_id, reseller)
      label = t('customers.form.field_default', n: label)
      html_options[:data] = { reseller_default: true }
    end
    html_options.empty? ? [label, value] : [label, value, html_options]
  end

  def router_option_is_reseller_default?(router, dimension, profile_id, reseller)
    return false if reseller.blank? || reseller.default_router_id.blank?
    return false if reseller.default_router_id != router.id
    return false if reseller.default_router_dimension != dimension

    profile_id.nil? || reseller.default_profile_id == profile_id
  end

  def router_option_label(router, _dimension = ROUTER_SELECT_DIMENSION)
    router.translated_name
  end

  def router_option_value(router, dimension, profile_id = nil)
    if profile_id
      "#{profile_id}_#{router.id}_#{dimension}"
    else
      "#{router.id}_#{dimension}"
    end
  end

end
