$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "mapotempo_web_stores_by_distance/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "mapotempo_web_stores_by_distance"
  s.version     = MapotempoWebStoresByDistance::VERSION
  s.authors     = ["Frédéric Rodrigo"]
  s.email       = ["fred.rodrigo@gmail.com"]
  s.homepage    = "http://mapotempo.com"
  s.summary     = "Mapotempo-Web store by distance."
  s.description = "Mapotempo-Web to expose store by distance from a point."
  s.license     = "AGPL"

  s.files = Dir["{app,config,db,lib}/**/*", "LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]
end
