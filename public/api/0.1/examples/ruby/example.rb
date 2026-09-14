#!/bin/env ruby
# REST API 0.1 examples. Replace the placeholders, then run: ruby example.rb
# See ../../getting-started.md for the happy path, pitfalls, and CSV headers.

begin
  require 'bundler/inline'
rescue LoadError => e
  $stderr.puts 'Bundler version 1.10 or later is required. Please update your Bundler'
  raise e
end

gemfile(true) do
  source 'https://rubygems.org' do
    gem 'addressable'
    gem 'rest-client'
  end
end

require 'addressable'
require 'rest-client'
require 'csv'
require 'json'
require 'tempfile'

API_KEY = '!!!your_secret_api_key!!!'
URL = 'http://localhost:3000'

def api(method, path, payload: nil, headers: {})
  RestClient::Request.execute(
    method: method,
    url: "#{URL}#{path}",
    payload: payload,
    headers: { 'Api-Key' => API_KEY, accept: :json }.merge(headers)
  )
end

def api_json(method, path, body = nil)
  payload = body && body.to_json
  headers = { content_type: :json }
  JSON.parse(api(method, path, payload: payload, headers: headers))
end

# EXAMPLE 1 — bootstrap: deliverable unit ids and vehicle refs
units = api_json(:get, '/api/0.1/deliverable_units.json')
puts 'Deliverable units: %s' % [units.map { |u| [u['id'], u['ref']] }.inspect]
vehicles = api_json(:get, '/api/0.1/vehicles.json')
puts 'Vehicles: %s' % [vehicles.map { |v| [v['id'], v['ref']] }.inspect]

# EXAMPLE 2 — create one destination with a nested visit
created = api_json(:post, '/api/0.1/destinations.json', {
  ref: 'CLIENT-12',
  name: 'Acme',
  street: '12 avenue Thiers',
  postalcode: '33100',
  city: 'Bordeaux',
  country: 'France',
  visits: [{
    ref: 'V1',
    duration: '00:10:00',
    time_window_start_1: '08:00',
    time_window_end_1: '12:00',
    quantities: [{ deliverable_unit_id: 1, delivery: 1.0 }]
  }]
})
puts 'Created destination id=%s' % [created['id']]

# EXAMPLE 3 — bulk upsert and create a planning when visits have a vehicle ref
imported = api_json(:put, '/api/0.1/destinations.json', {
  planning: { name: 'Monday', ref: 'PLAN-MON' },
  destinations: [{
    ref: 'CLIENT-12',
    name: 'Acme',
    street: '12 avenue Thiers',
    postalcode: '33100',
    city: 'Bordeaux',
    country: 'France',
    visits: [{
      duration: '00:10:00',
      time_window_start_1: '08:00',
      time_window_end_1: '12:00',
      route: 'VEH-1',
      active: true
    }]
  }]
})
puts 'Imported %s destinations' % [imported.length]

# EXAMPLE 4 — create a planning (routes and stops are materialized automatically)
planning = api_json(:post, '/api/0.1/plannings.json', {
  name: 'Monday',
  ref: 'PLAN-MON',
  date: '2026-09-14'
})
puts 'Planning id=%s route_ids=%s' % [planning['id'], planning['route_ids'].inspect]

# EXAMPLE 5 — CSV import (English headers). Use Accept-Language: fr with French headers.
csv = Tempfile.new(['destinations', '.csv'])
CSV.open(csv.path, 'wb') do |out|
  out << ['reference', 'name', 'street', 'postalcode', 'city', 'country', 'visit duration', 'open 1', 'close 1', 'delivery', 'vehicle', 'plan']
  out << ['CLIENT-12', 'Acme', '12 avenue Thiers', '33100', 'Bordeaux', 'France', '00:10:00', '08:00', '12:00', '1', 'VEH-1', 'Monday']
end
# French equivalent headers (Accept-Language: fr):
# référence,nom,voie,code postal,ville,pays,durée visite,horaire début 1,horaire fin 1,livraison,véhicule,plan
response = api(:put, '/api/0.1/destinations.json', payload: { multipart: true, file: File.open(csv.path) }, headers: { 'Accept-Language' => 'en' })
puts 'CSV import: %s destinations' % [JSON.parse(response).length]
csv.close!
