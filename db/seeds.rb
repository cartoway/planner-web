I18n.locale = :fr

mapnik_fr = Layer.create!(source: "osm", name: "Mapnik-fr", url: "http://tile-{s}.openstreetmap.fr/osmfr/{z}/{x}/{y}.png", urlssl: "https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png", attribution: "Tiles by OpenStreetMap-France")
mapnik = Layer.create!(source: "osm", name: "Mapnik", url: "http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", urlssl: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", attribution: "Tiles by OpenStreetMap")
stamen_bw = Layer.create!(source: "osm", name: "Stamen B&W", name_locale: {fr: "Stamen N&B"}, url: "http://{s}.tile.stamen.com/toner-lite/{z}/{x}/{y}.png", urlssl: "https://stamen-tiles-{s}.a.ssl.fastly.net/toner-lite/{z}/{x}/{y}.png", attribution: "Tiles by Stamen Design")
here_layer = Layer.create!(source: "here", name: "Here", url: "http://4.base.maps.cit.api.here.com/maptile/2.1/maptile/newest/normal.day/{z}/{x}/{y}/256/png8?app_id=#{ENV['HERE_APP_ID']}&app_code=YOUR_APP_CODE#{ENV['HERE_APP_CODE']}", urlssl: "https://4.base.maps.cit.api.here.com/maptile/2.1/maptile/newest/normal.day/{z}/{x}/{y}/256/png8?app_id=#{ENV['HERE_APP_ID']}&app_code=#{ENV['HERE_APP_CODE']}", attribution: "Here")

car = RouterWrapper.create!(
    mode: 'car',
    name: 'RouterWrapper-Car',
    name_locale: {fr: 'Calculateur pour voiture', en: 'Car router'},
    options: {time: true, distance: true, avoid_zones: false, isochrone: true, isodistance: true, approach: true, motorway: true})
bicycle = RouterWrapper.create!(
    mode: 'bicycle',
    name: 'RouterWrapper-Bicycle',
    name_locale: {fr: 'Calculateur pour vélo', en: 'Bicycle router'},
    options: {time: true, distance: true, avoid_zones: false, isochrone: true, isodistance: true})
pedestrian = RouterWrapper.create!(
    mode: 'pedestrian',
    name: 'RouterWrapper-Pedestrian',
    name_locale: {fr: 'Calculateur pour piéton', en: 'Pedestrian router'},
    options: {time: true, distance: true, avoid_zones: false, isochrone: true, isodistance: true})
here_car = RouterWrapper.create!(
    mode: 'car_here',
    name: 'RouterWrapper-HereCar',
    name_locale: {fr: 'Calculateur pour voiture monde avec trafic', en: 'Car worldwide with traffic router'},
    options: {time: true, distance: true, avoid_zones: true, isochrone: true, isodistance: true, motorway: true, toll: true, trailers: false, weight: false, weight_per_axle: false, height: false, width: false, length: false, hazardous_goods: false, strict_restriction: false, traffic: true})
here_truck = RouterWrapper.create!(
    mode: 'truck',
    name: 'RouterWrapper-HereTruck',
    name_locale: {fr: 'Calculateur pour camion', en: 'Truck router'},
    options: {time: true, distance: false, avoid_zones: true, isochrone: true, isodistance: false, motorway: true, toll: true, trailers: true, weight: true, weight_per_axle: true, height: true, width: true, length: true, hazardous_goods: true, strict_restriction: true, traffic: true})
public_transport = RouterWrapper.create!(
    mode: 'public_transport',
    name: 'RouterWrapper-PublicTransport',
    name_locale: {fr: 'Calculateur pour transport en commun', en: 'Public Transport router'},
    options: {time: true, distance: false, avoid_zones: false, isochrone: true, isodistance: true, max_walk_distance: true})

profile_osm = Profile.create!(name: "1. OSM", layers: [mapnik_fr, mapnik, stamen_bw], routers: [car, bicycle, pedestrian, public_transport])
profile_all = Profile.create!(name: "2. All", layers: [mapnik_fr, mapnik, stamen_bw, here_layer], routers: [car, bicycle, pedestrian, here_car, here_truck, public_transport])
profile_other = Profile.create!(name: "3. Other", layers: [mapnik_fr, mapnik, stamen_bw], routers: [car])

reseller = Reseller.create!(host: "localhost:3000", name: "Mapotempo", authorized_fleet_administration: true)
customer = Customer.create!(reseller: reseller, name: "Toto", default_country: "France", router: car, profile: profile_all, test: true, max_vehicles: 2, devices: {'fleet_demo' => {'enable' => '1'}})
admin = User.create!(email: "admin@example.com", password: "123", reseller: reseller, layer: mapnik)
test = User.create!(email: "test@example.com", password: "123", layer: mapnik, customer: customer)
toto = User.create!(email: "toto@example.com", password: "123", layer: mapnik, customer: customer)

Tag.create!(label: "lundi", customer: customer)
Tag.create!(label: "jeudi", customer: customer)
frigo = Tag.create!(label: "frigo", customer: customer)

Visit.create!(ref: 'v1', quantities: {customer.deliverable_units[0].id => 1}, destination: Destination.create!(name: "l1", street: "Place Picard", postalcode: "33000", city: "Bordeaux", lat: 44.84512, lng: -0.578, customer: customer))
Visit.create!(ref: 'v2', destination: Destination.create!(name: "l2", street: "Rue Esprit des Lois", postalcode: "33000", city: "Bordeaux", lat: 44.83395, lng: -0.56545, customer: customer))
Visit.create!(ref: 'v3', destination: Destination.create!(name: "l3", street: "Rue de Nuits", postalcode: "33000", city: "Bordeaux", lat: 44.84272, lng: -0.55013, customer: customer))
destination_4 = Destination.create!(name: "l4", street: "Rue de New York", postalcode: "33000", city: "Bordeaux", lat: 44.86576, lng: -0.57577, customer: customer)
Visit.create!(ref: 'v4-1', quantities: {customer.deliverable_units[0].id => 0.5}, destination: destination_4, tags: [frigo])
Visit.create!(ref: 'v4-2', quantities: {customer.deliverable_units[0].id => 0.5}, destination: destination_4)
