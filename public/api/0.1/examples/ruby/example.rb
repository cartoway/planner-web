#!/bin/env ruby

begin
  require 'bundler/inline'
rescue LoadError => e
  $stderr.puts 'Bundler version 1.10 or later is required. Please update your Bundler'
  raise e
end

gemfile(true) do
  source 'https://rubygems.org' do
    gem 'pry'
    gem 'addressable'
    gem 'rest-client'
  end
end

require 'pry'
require 'addressable'
require 'rest-client'
require 'csv'
require 'json'

API_KEY = '!!!your_secret_api_key!!!'
URL = 'http://0.0.0.0:3000'

def destinations_url
  Addressable::Template.new("%s/api/0.1/destinations.json{?query*}" % [ URL ]).expand(
    query: { api_key: API_KEY }
  ).to_s
end

# EXAMPLE 1
# get the destinations list from api_key user's customer
response = RestClient.get destinations_url
puts "Found %s destinations" % [ JSON.parse(response).length ]

# EXAMPLE 2
# post new destinations in json (will be automatically geocoded if lat/lng are missing)
def destination_hash index
  {
    ref: "ref-#{index}",
    name: "client-#{index}",
    street: "#{index} Test",
    postalcode: 75004,
    city: "Paris",
    country: "France",
    detail: "this is test #{index}",
    tag_ids: [],
    lat: 48.8562,
    lng: 2.3556,
    visits: [{
      time_window_start_1: "08:00",
      time_window_end_1: "12:00",
      time_window_start_2: "14:00",
      time_window_end_2: "18:00",
      duration: "00:10:00"
    }]
  }
end
response = RestClient.put destinations_url, { destinations: [destination_hash(1), destination_hash(2)] }.to_json, content_type: :json, accept: :json
puts "Imported %s destinations" % [ JSON.parse(response).length ]

# EXAMPLE 3
# same and create a planning at the same time
def destination_hash_with_route index
  {
    ref: "ref-#{index}",
    name: "client-#{index}",
    street: "#{index} Test",
    postalcode: 75004,
    city: "Paris",
    country: "France",
    detail: "this is test #{index}",
    tag_ids: [],
    lat: 48.8562,
    lng: 2.3556,
    visits: [{
      quantities: [{deliverable_unit_id: "!!!one_of_your_deliverable_unit_id!!!", quantity: 1.0}],
      time_window_start_1: "08:00",
      time_window_end_1: "12:00",
      time_window_start_2: "14:00",
      time_window_end_2: "18:00",
      duration: "00:10:00",
      route: "string",
      active: true
    }]
  }
end
response = RestClient.put destinations_url, {
  planning: {
    name: 'my plan'
    },
  destinations: [destination_hash_with_route(1), destination_hash_with_route(2)] # note the "route" key defines the targeted route if you have already this info for each visit in created plan
}.to_json, content_type: :json, accept: :json
puts "Imported %s destinations and created plan" % [ JSON.parse(response).length ]

# EXAMPLE 4
# import destinations and create a new planning by uploading csv using cURL
CSV.open("/tmp/planner_csv", "wb") do |csv|
  csv << ["référence","nom","voie","complément","code postal","ville","lat","lng","tournée","catégories","livré"]
  csv << ["ref-id","Test Name","123 Test","","33000","Bordeaux","44.8798","-0.544917","planning-1","tag-1","T"]
end
# Send Accept-Language => "en" headers when parsing files with header columns in english
response = RestClient::Request.execute method: :put, url: destinations_url, headers: { "Accept-Language" => "fr" }, payload: { multipart: true, file: File.open("/tmp/planner_csv") }
