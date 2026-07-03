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
      record_customer = Customer.joins(:destinations).distinct.first || Customer.first
      @customer = record_customer || Lookbook::DestinationsListSample.customer
      allowed = Preferences::Catalog.destinations_list_allowed_column_ids(@customer)
      @destinations_list_columns = (
        Preferences::Catalog::DestinationsList.default_active_for(@customer) + %w[tags visit_tags]
      ).uniq & allowed

      if record_customer&.destinations&.exists?
        scope = record_customer.destinations.includes([:tags, { visits: :tags }]).reorder(:id)
        @total_count = scope.count
        @destinations = scope.limit(3).to_a
        @lookbook_destinations_list_demo = false
      else
        @destinations = Lookbook::DestinationsListSample.destinations_for(@customer)
        @total_count = 42
        @lookbook_destinations_list_demo = true
      end

      @pagination = { page: 2, per_page: 25, total: [@total_count, 60].max }
    end

    # Lookbook does not copy preview instance variables into the template — pass explicit assigns.
    def destinations_list_lookbook_assigns
      {
        assigns: {
          customer: @customer,
          destinations: @destinations,
          destinations_list_columns: @destinations_list_columns,
          total_count: @total_count,
          pagination: @pagination,
          lookbook_destinations_list_demo: @lookbook_destinations_list_demo
        }
      }
    end
  end
end
