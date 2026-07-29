# frozen_string_literal: true

module UserPreferences::DestinationsIndex
  def destinations_index_version
    ::Preferences::Catalog::Headers.normalize_destinations_index_config(read_headers_hash['destinations_index'])['version']
  end

  def destinations_index_v2?
    destinations_index_version == ::Preferences::Catalog::Headers::DESTINATIONS_INDEX_V2
  end

  def destinations_index_per_page
    ::Preferences::Catalog::Headers.normalize_destinations_index_config(read_headers_hash['destinations_index'])['per_page']
  end

  def destinations_list_columns_split(customer = nil)
    customer ||= self.customer if respond_to?(:customer)
    z = read_headers_hash['destinations_list']
    h = ::Preferences::Catalog::DestinationsList.normalize_zone(z, customer: customer)
    [h['active'], h['hidden']]
  end

  def destinations_list_active_column_ids(customer = nil)
    destinations_list_columns_split(customer).first
  end
end
