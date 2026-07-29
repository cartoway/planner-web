# frozen_string_literal: true

# In-memory destinations for the Lookbook tables/destinations_list preview when the DB has none.
module Lookbook
  module DestinationsListSample
    module_function

    def customer
      DestinationsListSampleModels::Customer.new(id: 0)
    end

    def destinations_for(_customer = nil)
      urgent = DestinationsListSampleModels::Tag.new(id: 1, label: 'Urgent', color: '#c0392b', icon: nil)
      retail = DestinationsListSampleModels::Tag.new(id: 2, label: 'Retail', color: nil, icon: 'fa-shopping-bag')
      visit_cat = DestinationsListSampleModels::Tag.new(id: 3, label: 'Livraison', color: '#2980b9', icon: 'fa-truck')

      [
        DestinationsListSampleModels::Destination.new(
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
          duration_time_with_seconds: '00:05:00',
          tags: [urgent, retail],
          visits: [
            DestinationsListSampleModels::Visit.new(ref: 'V-001', tags: [visit_cat], deliveries: { 1 => 2.0 }, duration_time_with_seconds: '00:10:00'),
            DestinationsListSampleModels::Visit.new(ref: 'V-002', tags: [visit_cat], deliveries: { 1 => 1.5 }, duration_time_with_seconds: '00:07:00')
          ]
        ),
        DestinationsListSampleModels::Destination.new(
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
          visits: [DestinationsListSampleModels::Visit.new(tags: [])]
        ),
        DestinationsListSampleModels::Destination.new(
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
        ),
        DestinationsListSampleModels::Destination.new(
          id: 10_004,
          name: 'Point approximatif',
          ref: 'CLI-004',
          street: 'Parc logistique Ouest',
          postalcode: '33700',
          city: 'Mérignac',
          country: 'France',
          lat: 44.835,
          lng: -0.69,
          comment: 'Précision faible',
          phone_number: '+33 5 56 00 00 04',
          geocoding_level: 'city',
          geocoding_accuracy: 0.18,
          geocoding_result: { 'free' => 'Parc logistique Ouest, Mérignac' },
          tags: [],
          visits: [DestinationsListSampleModels::Visit.new(tags: [])]
        )
      ]
    end
  end
end
