# frozen_string_literal: true

# Copyright © Cartoway
#
# Applies DestinationSearchParser conditions to a Destination scope.
# Uses ILIKE for case-insensitive partial matching (minimum 3 chars recommended).
class DestinationSearchScope
  def self.apply(scope, conditions)
    new(scope).apply(conditions)
  end

  def initialize(scope)
    @scope = scope
  end

  def apply(conditions)
    conditions.each do |c|
      @scope = apply_condition(@scope, c[:key], c[:value])
    end
    @scope
  end

  private

  def apply_condition(scope, key, value)
    return scope if value.blank?

    pattern = "%#{scope.connection.quote_string(value)}%"

    case key
    when 'ref' then scope.where('destinations.ref ILIKE ?', pattern)
    when 'name' then scope.where('destinations.name ILIKE ?', pattern)
    when 'address' then scope.where(
      'destinations.street ILIKE ? OR destinations.postalcode ILIKE ? OR destinations.city ILIKE ? OR destinations.country ILIKE ?',
      pattern, pattern, pattern, pattern
    )
    when 'city' then scope.where('destinations.city ILIKE ?', pattern)
    when 'postalcode' then scope.where('destinations.postalcode ILIKE ?', pattern)
    when 'country' then scope.where('destinations.country ILIKE ?', pattern)
    when 'phone' then scope.where('destinations.phone_number ILIKE ?', pattern)
    when 'comment' then scope.where('destinations.comment ILIKE ?', pattern)
    when 'tags' then scope.joins(:tags).where('tags.label ILIKE ?', pattern).distinct
    when 'visit_ref' then scope.joins(:visits).where('visits.ref ILIKE ?', pattern).distinct
    when 'visit_tags' then scope.joins(visits: :tags).where('tags.label ILIKE ?', pattern).distinct
    when 'q'
      scope.where(
        'destinations.name ILIKE ? OR destinations.city ILIKE ? OR destinations.street ILIKE ? OR destinations.postalcode ILIKE ? OR destinations.country ILIKE ?',
        pattern, pattern, pattern, pattern, pattern
      )
    else scope
    end
  end
end
