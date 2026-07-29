# frozen_string_literal: true

module DesignSystem
  class TablesPreview < ApplicationPreview
    include DestinationsHelper
    include TagsHelper

    def destinations_list
      load_lookbook_destinations_list_data
      render_with_template.merge(destinations_list_lookbook_assigns)
    end

    def compact_and_striped
      render_with_template
    end

    private

    def load_lookbook_destinations_list_data
      @customer = Lookbook::DestinationsListSample.customer
      allowed = Preferences::Catalog.destinations_list_allowed_column_ids(@customer)
      @destinations_list_columns = (
        Preferences::Catalog::DestinationsList.default_active_for(@customer) + %w[tags visit_tags]
      ).uniq & allowed

      @destinations = Lookbook::DestinationsListSample.destinations_for(@customer)
      @total_count = 42
      @pagination = { page: 5, per_page: 25, total: 250 }
    end

    # Lookbook does not copy preview instance variables into the template — pass explicit assigns.
    def destinations_list_lookbook_assigns
      {
        assigns: {
          customer: @customer,
          destinations: @destinations,
          destinations_list_columns: @destinations_list_columns,
          total_count: @total_count,
          pagination: @pagination
        }
      }
    end
  end
end
