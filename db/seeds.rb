I18n.locale = :fr

mapnik_fr = Layer.create!(source: "osm", name: "Mapnik-fr", url: "http://a.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png", urlssl: "https://a.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png", attribution: "Tiles by OpenStreetMap-France")
mapnik = Layer.create!(source: "osm", name: "Mapnik", url: "http://tile.openstreetmap.org/{z}/{x}/{y}.png", urlssl: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", attribution: "Tiles by OpenStreetMap")
stamen_bw = Layer.create!(source: "osm", name: "Stamen B&W", name_locale: {fr: "Stamen N&B"}, url: "http://{s}.tile.stamen.com/toner-lite/{z}/{x}/{y}.png", urlssl: "https://stamen-tiles-{s}.a.ssl.fastly.net/toner-lite/{z}/{x}/{y}.png", attribution: "Tiles by Stamen Design")
here_layer = Layer.create!(source: "here", name: "Here", url: "https://maps.hereapi.com/v3/base/mc/{z}/{x}/{y}/png?style=logistics.day&apiKey=#{ENV['HERE_MAP_APIKEY']}", urlssl: "https://maps.hereapi.com/v3/base/mc/{z}/{x}/{y}/png?style=logistics.day&apiKey=#{ENV['HERE_MAP_APIKEY']}", attribution: "Here")

car = RouterWrapper.create!(
    mode: 'car',
    name: 'RouterWrapper-Car',
    name_locale: {fr: 'Calculateur pour véhicule utilitaire léger', en: 'Light commercial vehicle router'},
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
    name_locale: {fr: 'Calculateur pour véhicule utilitaire léger monde avec trafic', en: 'Light commercial vehicle worldwide with traffic router'},
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

reseller = Reseller.create!(host: "localhost:8080", name: "Planner Web", authorized_fleet_administration: true)
customer = Customer.create!(reseller: reseller, name: "Toto", default_country: "France", router: car, profile: profile_all, test: true, max_vehicles: 2)
admin = User.create!(email: "admin@example.com", password: "12345678", reseller: reseller, layer: mapnik)
test = User.create!(email: "test@example.com", password: "12345678", layer: mapnik, customer: customer)
toto = User.create!(email: "toto@example.com", password: "12345678", layer: mapnik, customer: customer)

Tag.create!(label: "lundi", customer: customer)
Tag.create!(label: "jeudi", customer: customer)
frigo = Tag.create!(label: "frigo", customer: customer)

Visit.create!(ref: 'v1', deliveries: {customer.deliverable_units[0].id => 1}, destination: Destination.create!(name: "l1", street: "Boulevard de Grenelle", postalcode: "75015", city: "Paris", lat: 48.84137, lng: 2.3003, customer: customer))
Visit.create!(ref: 'v2', destination: Destination.create!(name: "l2", street: "Place d'Italie", postalcode: "75013", city: "Paris", lat: 48.83239, lng: 2.355583, customer: customer))
Visit.create!(ref: 'v3', destination: Destination.create!(name: "l3", street: "Boulevard Voltaire", postalcode: "75011", city: "Paris", lat: 48.85841, lng: 2.37970, customer: customer))
destination_4 = Destination.create!(name: "l4", street: "Avenue de la Porte de Vincennes", postalcode: "75020", city: "Paris", lat: 48.86504, lng: 2.39893, customer: customer)
Visit.create!(ref: 'v4-1', deliveries: {customer.deliverable_units[0].id => 0.5}, destination: destination_4, tags: [frigo])
Visit.create!(ref: 'v4-2', deliveries: {customer.deliverable_units[0].id => 0.5}, destination: destination_4)
