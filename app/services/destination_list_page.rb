# frozen_string_literal: true

# Copyright © Cartoway
#
# 1-based page of one destination in the v2 list order.
# Used when a map marker is not on the current page. The map payload does not carry pages.
class DestinationListPage
  def self.for(scope:, destination_id:, per_page:)
    new(scope, destination_id, per_page).number
  end

  def initialize(scope, destination_id, per_page)
    @scope = scope
    @destination_id = destination_id.to_i
    @per_page = per_page.to_i.clamp(1, 100)
  end

  def number
    return nil if @destination_id <= 0

    order_sql = self.class.order_sql(@scope)
    return nil if order_sql.blank?

    ids = @scope.except(:order, :includes, :preload, :eager_load).reselect(Arel.sql('destinations.id')).distinct
    ranked = Destination.unscoped.where(id: ids).select(Arel.sql(<<~SQL.squish))
      destinations.id AS id,
      ((ROW_NUMBER() OVER (ORDER BY #{order_sql}) - 1) / #{@per_page}) + 1 AS list_page
    SQL
    page = Destination.unscoped.from(ranked, :ranked_destinations)
      .where('ranked_destinations.id = ?', @destination_id)
      .pick(Arel.sql('list_page'))
    page&.to_i
  end

  # Scope ORDER BY, built by DestinationsListSort / the controller. Not raw user input.
  def self.order_sql(scope)
    scope.order_values.filter_map { |value|
      sql = value.respond_to?(:to_sql) ? value.to_sql : value.to_s
      sql.presence
    }.join(', ')
  end
end
