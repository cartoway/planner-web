$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "mapotempo_web_import_vehicle_store/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "mapotempo_web_import_vehicle_store"
  s.version     = MapotempoWebImportVehicleStore::VERSION
  s.authors     = ["Frédéric Rodrigo"]
  s.email       = ["fred.rodrigo@gmail.com"]
  s.homepage    = "http://mapotempo.com"
  s.summary     = "Mapotempo-Web import vehicles and stores."
  s.description = "Mapotempo-Web import at once vehicles, vehicle_usages and stores with only one vehicle_usage_set present."
  s.license     = "AGPL"

  s.files = Dir["{app,config,db,lib}/**/*", "LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]
end
