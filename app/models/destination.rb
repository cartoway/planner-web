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
class Destination < Location
  default_scope { order(:id) }

  has_many :visits, inverse_of: :destination, dependent: :delete_all
  accepts_nested_attributes_for :visits, allow_destroy: true
  has_many :tag_destinations
  has_many :tags, through: :tag_destinations, after_add: :update_tags_track, after_remove: :update_tags_track

  auto_strip_attributes :name, :street, :postalcode, :city, :country, :detail, :comment, :phone_number

  include Consistency
  validate_consistency :tags

  before_create :check_max_destination
  before_save :save_visits, :update_tags
  after_save -> { @tag_ids_changed = false }

  include RefSanitizer

  scope :includes_visits, -> { includes([{visits: :tags}, :tags]) }
  scope :positioned, -> { where.not(lat: nil).where.not(lng: nil) }
  scope :not_positioned, -> { where('lat IS NULL OR lng IS NULL') }

  amoeba do
    enable

    customize(lambda { |_original, copy|
      def copy.update_tags; end
    })
  end

  include LocalizedAttr

  attr_localized :lat, :lng, :geocoding_accuracy

  def destroy
    # Too late to do this in before_destroy callback, children already destroyed
    Visit.transaction do
      visits.destroy_all
    end
    super
  end

  def changed?
    @tag_ids_changed || super
  end

  def visits_color
    (tags | visits.flat_map(&:tags).uniq).find(&:color).try(&:color)
  end

  def visits_icon
    (tags | visits.flat_map(&:tags).uniq).find(&:icon).try(&:icon)
  end

  def visits_icon_size
    (tags | visits.flat_map(&:tags).uniq).find(&:icon).try(&:icon_size)
  end

  def update_tags_track(_tag)
    @tag_ids_changed = true
  end

  private

  def tag_ids_changed?
    @tag_ids_changed
  end

  def check_max_destination
    !self.customer.too_many_destinations? || raise(Exceptions::OverMaxLimitError.new(I18n.t('activerecord.errors.models.customer.attributes.destinations.over_max_limit')))
  end

  def save_visits
    return if self.new_record?

    visits.each(&:save!)
  end

  def update_tags
    if customer && (@tag_ids_changed || new_record?)
      # Don't use local collection here, not set when save new record
      customer.plannings.each do |planning|
        visits.select(&:id).each do |visit|
          if !new_record? && planning.visits_include?(visit)
            if planning.tag_operation == '_or'
              unless (planning.tags.to_a & (tags.to_a | visit.tags.to_a)).present?
                planning.visit_remove(visit)
              end
            elsif planning.tags.to_a & (tags.to_a | visit.tags.to_a) != planning.tags.to_a
              planning.visit_remove(visit)
            end
          elsif planning.tags_compatible?(tags.to_a | visit.tags.to_a)
            planning.visit_add(visit)
          end
        end
      end
    end
    outdated if @tag_ids_changed && !new_record?

    true
  end

  def outdated
    Route.transaction do
      visits.each(&:outdated)
    end
  end
end
