# Copyright © Mapotempo, 2016
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
task :test do
  # Rake::Task['assets:precompile'].invoke # Seems to be taken into account after in next replay...
  `bin/webpack`
  Rake::Task['test'].invoke
end

# # Disable brakeman as causin test issue with Ruby 2.6
#
# begin
#   Rake::Task['test'].enhance do
#     if !ENV.key?('BRAKEMAN') || ENV['BRAKEMAN'] != 'false'
#       require 'brakeman'
#       Brakeman.run app_path: '.', print_report: true
#     end
#   end
# rescue Gem::LoadError
# end
