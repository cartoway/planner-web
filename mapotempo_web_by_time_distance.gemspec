$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "mapotempo_web_by_time_distance/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "mapotempo_web_by_time_distance"
  s.version     = MapotempoWebByTimeDistance::VERSION
  s.authors     = ["Frédéric Rodrigo"]
  s.email       = ["fred.rodrigo@gmail.com"]
  s.homepage    = "http://mapotempo.com"
  s.summary     = "Mapotempo-Web destinations by time/distance."
  s.description = "Mapotempo-Web to expose destinations and stores by time/distance from a point."
  s.license     = "AGPL"

  s.files = Dir["{app,config,db,lib}/**/*", "LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]
end
