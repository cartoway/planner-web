# frozen_string_literal: true

module Lookbook
  module DestinationsListSampleModels
    Customer = Struct.new(:id, keyword_init: true) do
      def enable_references?
        true
      end

      def is_editable? # rubocop:disable Naming/PredicatePrefix -- matches Customer#is_editable?
        true
      end

      def deliverable_units
        []
      end
    end

    Tag = Struct.new(:id, :label, :color, :icon, keyword_init: true) do
      def default_color
        color.presence || Planner::Application.config.tag_color_default
      end

      def default_icon
        icon.presence || Planner::Application.config.destination_icon_default
      end
    end

    Visit = Struct.new(:ref, :tags, :pickups, :deliveries, :duration_time_with_seconds, keyword_init: true) do
      def initialize(ref: nil, tags: [], pickups: {}, deliveries: {}, duration_time_with_seconds: nil)
        super
      end

      def default_pickups
        pickups
      end

      def default_deliveries
        deliveries
      end
    end

    Destination = Struct.new(
      :id,
      :name,
      :ref,
      :street,
      :postalcode,
      :city,
      :country,
      :lat,
      :lng,
      :comment,
      :phone_number,
      :geocoding_level,
      :geocoding_accuracy,
      :geocoding_result,
      :duration_time_with_seconds,
      :tags,
      :visits,
      keyword_init: true
    ) do
      def position?
        !lat.nil? && !lng.nil?
      end

      def geocode_progress_bar_class
        return unless geocoding_accuracy

        if geocoding_accuracy > Planner::Application.config.geocoder.accuracy_success
          'success'
        elsif geocoding_accuracy > Planner::Application.config.geocoder.accuracy_warning
          'warning'
        else
          'danger'
        end
      end
    end
  end
end
