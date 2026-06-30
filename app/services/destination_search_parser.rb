# frozen_string_literal: true

# Copyright © Cartoway
#
# Parses key:value search queries for destinations index.
# Format: field:value (e.g. name:Dupont, city:Lyon or nom:Dupont, ville:Lyon in French)
# Keys accept both internal (English) and localized names via I18n.
# Multiple filters are separated by whitespace only before the next known key (values may contain spaces).
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

    if @query.include?(':')
      parse_key_value_pairs
    else
      # Fallback: global search on name, city, address
      [{ key: 'q', value: @query }]
    end
  end

  private

  def parse_key_value_pairs
    split_filter_segments(@query).filter_map do |segment|
      key, value = segment.split(':', 2)
      next if value.blank?

      internal_key = resolve_key(key.to_s.strip)
      { key: internal_key, value: value.strip } if internal_key
    end
  end

  # Split on whitespace that precedes a known filter key, not on spaces inside values.
  def split_filter_segments(query)
    key_pattern = localized_keys_pattern
    boundary = /(?:(?<=\A)|(?<=\s))(?<key>#{key_pattern}):/i
    matches = query.enum_for(:scan, boundary).map { Regexp.last_match }
    return [query.strip] if matches.empty?

    matches.each_with_index.map do |match, index|
      start = match.begin(0)
      stop = matches[index + 1]&.begin(0) || query.length
      query[start...stop].strip
    end
  end

  def localized_keys_pattern
    keys = ALLOWED_KEYS.flat_map do |internal|
      localized = I18n.with_locale(@locale) do
        I18n.t("destinations.index.search_keys.#{internal}", default: internal).to_s
      end
      [internal, localized]
    end.uniq
    keys.sort_by(&:length).reverse.map { |key| Regexp.escape(key) }.join('|')
  end

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
