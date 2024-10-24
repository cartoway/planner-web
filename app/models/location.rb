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
class LocalizationValidator < ActiveModel::Validator
  def validate(record)
    if record.postalcode.nil? && record.city.nil? && !record.position?
      record.errors.add(:base, message: I18n.t('activerecord.errors.models.location.missing_address_or_latlng'))
    end
  end
end

class Location < ApplicationRecord
  GEOCODING_LEVEL = {point: 1, house: 2, intersection: 3, street: 4, city: 5}.freeze

  self.abstract_class = true

  enum geocoding_level: GEOCODING_LEVEL

  belongs_to :customer

  nilify_blanks before: :validation
  validates :customer, presence: true
  validates :name, presence: true
  # validates :street, presence: true
  # validates :city, presence: true
  validates :lat, numericality: {only_float: true}, allow_nil: true
  validates :lng, numericality: {only_float: true}, allow_nil: true
  validates_inclusion_of :lat, in: -90..90, allow_nil: true, message: ->(*_) { I18n.t('activerecord.errors.models.location.lat_outside_range') }
  validates_inclusion_of :lng, in: -180..180, allow_nil: true, message: ->(*_) { I18n.t('activerecord.errors.models.location.lng_outside_range') }
  validates_inclusion_of :geocoding_accuracy, in: 0..1, allow_nil: true, message: ->(*_) { I18n.t('activerecord.errors.models.location.geocoding_accuracy_outside_range') }
  validates_with LocalizationValidator, fields: [:street, :city, :lat, :lng]

  before_validation :update_geocode, unless: -> { validation_context == :import }
  before_update :update_outdated

  def position?
    !lat.nil? && !lng.nil?
  end

  def geocode
    geocode_result(Mapotempo::Application.config.geocoder.code(*geocode_args))
  rescue GeocodeError => e # avoid stop save
    @warnings = [I18n.t('errors.location.geocoding_fail') + ' ' + e.message]
    Rails.logger.info "Destination Geocode Failed: ID=#{self.id}"
  end

  def reverse_geocoding(lat, lng)
    json = ActiveSupport::JSON.decode(Mapotempo::Application.config.geocoder.reverse(lat, lng))
    if json['features'].present?
      {
        success: true,
        geocoder_info: { geocoder_version: json['geocoding']['version'], geocoded_at: Time.now },
        result: json['features'].first['properties']['geocoding']
      }
    end
  rescue GeocodeError => e
    @warnings = {
      success: false,
      message: I18n.t('errors.location.reversegeocoding_fail') + ' ' + e.message
    }
  end

  def geocode_args
    [street, postalcode, city, state, !country.nil? && !country.empty? ? country : customer.try(&:default_country)]
  end

  def geocode_progress_bar_class
    return unless self.geocoding_accuracy

    if self.geocoding_accuracy > Mapotempo::Application.config.geocoder.accuracy_success
      'success'
    elsif self.geocoding_accuracy > Mapotempo::Application.config.geocoder.accuracy_warning
      'warning'
    else
      'danger'
    end
  end

  def geocode_result(address)
    if address
      self.geocoding_result = address
      self.geocoder_version = address[:geocoder_version]
      self.geocoded_at = address[:geocoded_at]

      self.lat, self.lng, self.geocoding_accuracy, self.geocoding_level = address[:lat], address[:lng], address[:accuracy], address[:quality]
    else
      self.lat = self.lng = self.geocoding_accuracy = self.geocoding_level = self.geocoder_version = self.geocoded_at = nil
    end
    @is_gecoded = true
  end

  def delay_geocode
    if lat_changed? || lng_changed?
      self.geocoding_result = {}
      self.geocoding_accuracy = nil
      self.geocoding_level = lat && lng ? :point : nil
    end
    @is_gecoded = true
  end

  def distance(position)
    lat && lng && position.lat && position.lng && Math.hypot(position.lat - lat, position.lng - lng)
  end

  def warnings
    @warnings
  end

  private

  def update_outdated
    if lat_changed? || lng_changed?
      outdated
    end
  end

  def update_geocode
    if self.id.nil?
      if !@is_gecoded && (lat.nil? || lng.nil?)
        geocode
      end
    else
      # when lat/lng are specified manually, geocoding_accuracy has no sense
      if !@is_gecoded && self.point? && (lat_changed? || lng_changed?)
        self.geocoding_result = {}
        self.geocoding_accuracy = nil
      end
      if position?
        @is_gecoded = true
      end
      if !@is_gecoded && (street_changed? || postalcode_changed? || city_changed? || state_changed? || country_changed?)
        geocode
      end
    end
  end
end
