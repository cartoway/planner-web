# frozen_string_literal: true

# In-memory destinations for the Lookbook tables/destinations_list preview when the DB has none.
module Lookbook
  module DestinationsListSample
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

    Tag = Struct.new(:id, :label, :color, :icon, keyword_init: true)

    Visit = Struct.new(:ref, :tags, :pickups, :deliveries, keyword_init: true) do
      def initialize(ref: nil, tags: [], pickups: {}, deliveries: {})
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

    module_function

    def customer
      Customer.new(id: 0)
    end

    def destinations_for(_customer = nil)
      urgent = Tag.new(id: 1, label: 'Urgent', color: '#c0392b', icon: nil)
      retail = Tag.new(id: 2, label: 'Retail', color: nil, icon: 'fa-shopping-bag')
      visit_cat = Tag.new(id: 3, label: 'Livraison', color: '#2980b9', icon: 'fa-truck')

      [
        Destination.new(
          id: 10_001,
          name: 'Boulangerie Dupont',
          ref: 'CLI-001',
          street: '12 rue des Lilas',
          postalcode: '33000',
          city: 'Bordeaux',
          country: 'France',
          lat: 44.8378,
          lng: -0.5792,
          comment: 'Entrée côté cour',
          phone_number: '+33 5 56 00 00 01',
          geocoding_level: 'house',
          geocoding_accuracy: 0.92,
          geocoding_result: { 'free' => '12 rue des Lilas, 33000 Bordeaux' },
          tags: [urgent, retail],
          visits: [
            Visit.new(ref: 'V-001', tags: [visit_cat], deliveries: { 1 => 2.0 }),
            Visit.new(ref: 'V-002', tags: [visit_cat], deliveries: { 1 => 1.5 })
          ]
        ),
        Destination.new(
          id: 10_002,
          name: 'Garage Martin',
          ref: 'CLI-002',
          street: '5 avenue de la Gare',
          postalcode: '33100',
          city: 'Bordeaux',
          country: 'France',
          lat: 44.8624,
          lng: -0.5510,
          comment: nil,
          phone_number: nil,
          geocoding_level: 'street',
          geocoding_accuracy: 0.55,
          geocoding_result: { 'free' => '5 avenue de la Gare, Bordeaux' },
          tags: [],
          visits: [Visit.new(tags: [])]
        ),
        Destination.new(
          id: 10_003,
          name: 'Adresse à géocoder',
          ref: 'CLI-003',
          street: 'Zone industrielle Nord',
          postalcode: nil,
          city: 'Mérignac',
          country: 'France',
          lat: nil,
          lng: nil,
          comment: 'Sans coordonnées',
          phone_number: '+33 5 56 00 00 03',
          geocoding_level: nil,
          geocoding_accuracy: nil,
          geocoding_result: nil,
          tags: [retail],
          visits: []
        )
      ]
    end
  end
end
