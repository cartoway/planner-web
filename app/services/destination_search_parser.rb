# frozen_string_literal: true

# Copyright © Cartoway
#
# Parses key:value search queries for destinations index.
# Format: field:value (e.g. name:Dupont, city:Lyon or nom:Dupont, ville:Lyon in French)
# Keys accept both internal (English) and localized names via I18n.
#
# Fallback: plain text without colon searches on name, city, and address.
class DestinationSearchParser
  ALLOWED_KEYS = %w[
    ref name address city postalcode country phone comment
    tags visit_ref visit_tags
  ].freeze

  # Parses a query string into filter conditions.
  # Returns array of hashes: [{ key: 'name', value: 'Dupont' }, ...]
  # For plain text (no colon), returns [{ key: 'q', value: 'text' }] for fallback search.
  def self.parse(query, locale: I18n.locale)
    new(query, locale: locale).parse
  end

  def initialize(query, locale: I18n.locale)
    @query = query.to_s.strip
    @locale = locale
  end

  def parse
    return [] if @query.blank?

    conditions = []
    if @query.include?(':')
      @query.split(/\s+/).each do |part|
        key, value = part.split(':', 2)
        next if value.blank?

        internal_key = resolve_key(key.to_s.strip)
        conditions << { key: internal_key, value: value.strip } if internal_key
      end
    else
      # Fallback: global search on name, city, address
      conditions << { key: 'q', value: @query }
    end
    conditions
  end

  private

  def resolve_key(user_key)
    key_down = user_key.downcase
    return key_down if ALLOWED_KEYS.include?(key_down)

    I18n.with_locale(@locale) do
      ALLOWED_KEYS.each do |internal|
        localized = I18n.t("destinations.index.search_keys.#{internal}", default: internal).to_s.downcase
        return internal if localized == key_down
      end
    end
    nil
  end
end
