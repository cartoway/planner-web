# frozen_string_literal: true

# Server-side sort for the v2 destinations index list.
class DestinationsListSort
  DIRECTIONS = %w[asc desc].freeze

  attr_reader :column_id, :direction

  def self.parse(params, customer:)
    column_id = params[:sort].to_s.presence
    return nil unless column_id && sortable_column?(column_id, customer: customer)

    direction = params[:direction].to_s.downcase == 'desc' ? 'desc' : 'asc'
    new(column_id: column_id, direction: direction, customer: customer)
  end

  def self.sortable_column?(column_id, customer:)
    id = column_id.to_s
    return false if id.blank?

    ::Preferences::Catalog::DestinationsList.column_available?(id, customer)
  end

  def initialize(column_id:, direction:, customer:)
    @column_id = column_id.to_s
    @direction = DIRECTIONS.include?(direction.to_s) ? direction.to_s : 'asc'
    @customer = customer
  end

  def apply(scope)
    scope.reorder(Arel.sql("#{order_expression}, destinations.id ASC"))
  end

  def active?
    column_id.present?
  end

  def next_direction_for(column_id)
    if self.column_id == column_id.to_s
      direction == 'asc' ? 'desc' : 'asc'
    else
      'asc'
    end
  end

  private

  attr_reader :customer

  def order_expression
    nulls = direction == 'asc' ? 'NULLS LAST' : 'NULLS FIRST'
    dir = direction.upcase
    case column_id
    when 'name' then "destinations.name #{dir} #{nulls}"
    when 'street' then "destinations.street #{dir} #{nulls}"
    when 'postalcode' then "destinations.postalcode #{dir} #{nulls}"
    when 'city' then "destinations.city #{dir} #{nulls}"
    when 'ref' then "destinations.ref #{dir} #{nulls}"
    when 'geocoding' then "destinations.geocoding_accuracy #{dir} #{nulls}"
    when 'comment' then "destinations.comment #{dir} #{nulls}"
    when 'phone_number' then "destinations.phone_number #{dir} #{nulls}"
    when 'destination_duration' then "destinations.duration #{dir} #{nulls}"
    when 'tags' then "#{destination_tags_sort_sql} #{dir} #{nulls}"
    when 'visit_duration' then "#{first_visit_duration_sort_sql} #{dir} #{nulls}"
    when 'visit_ref' then "#{first_visit_ref_sort_sql} #{dir} #{nulls}"
    when 'visit_tags' then "#{first_visit_tags_sort_sql} #{dir} #{nulls}"
    else
      du_id = ::Preferences::Catalog::DestinationsList.parse_deliverable_unit_column_id(column_id)
      if du_id
        "#{first_visit_deliverable_unit_sort_sql(du_id)} #{dir} #{nulls}"
      else
        'destinations.id ASC'
      end
    end
  end

  def destination_tags_sort_sql
    <<~SQL.squish
      (
        SELECT MIN(tags.label)
        FROM tags
        INNER JOIN tag_destinations ON tag_destinations.tag_id = tags.id
        WHERE tag_destinations.destination_id = destinations.id
      )
    SQL
  end

  def first_visit_id_sql
    '(SELECT MIN(visits.id) FROM visits WHERE visits.destination_id = destinations.id)'
  end

  def first_visit_ref_sort_sql
    <<~SQL.squish
      (
        SELECT visits.ref
        FROM visits
        WHERE visits.destination_id = destinations.id
        ORDER BY visits.id ASC
        LIMIT 1
      )
    SQL
  end

  def first_visit_duration_sort_sql
    <<~SQL.squish
      (
        SELECT visits.duration
        FROM visits
        WHERE visits.destination_id = destinations.id
        ORDER BY visits.id ASC
        LIMIT 1
      )
    SQL
  end

  def first_visit_tags_sort_sql
    <<~SQL.squish
      (
        SELECT MIN(tags.label)
        FROM visits
        INNER JOIN tag_visits ON tag_visits.visit_id = visits.id
        INNER JOIN tags ON tags.id = tag_visits.tag_id
        WHERE visits.destination_id = destinations.id
          AND visits.id = #{first_visit_id_sql}
      )
    SQL
  end

  def first_visit_deliverable_unit_sort_sql(du_id)
    key = ActiveRecord::Base.connection.quote(du_id.to_s)
    <<~SQL.squish
      (
        SELECT
          COALESCE(NULLIF(visits.deliveries->>#{key}, '')::double precision, 0) +
          COALESCE(NULLIF(visits.pickups->>#{key}, '')::double precision, 0)
        FROM visits
        WHERE visits.destination_id = destinations.id
        ORDER BY visits.id ASC
        LIMIT 1
      )
    SQL
  end
end
