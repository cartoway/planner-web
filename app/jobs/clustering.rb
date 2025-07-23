# Copyright © Mapotempo, 2015
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

require 'ai4r'
include Ai4r::Data
require 'k_means_same_size'
include Ai4r::Clusterers
require 'concave_hull'

include RGeo

class Clustering

  # Cluster non duplicate points
  def self.clustering(vector, n)
    if vector.empty?
      []
    else
      data_set = DataSet.new(data_items: vector.size.times.collect{ |i| [i] })
      c = KMeansSameSize.new
      c.set_parameters(max_iterations: 100)
      c.centroid_function = lambda do |data_sets|
        data_sets.collect{ |data_set|
          data_set.data_items.min_by{ |i|
            data_set.data_items.sum{ |j|
              c.distance_function.call(i, j)**2
            }
          }
        }
      end

      c.distance_function = lambda do |a, b|
        a = a[0]
        b = b[0]
        Math.sqrt((vector[a][0] - vector[b][0])**2 + (vector[a][1] - vector[b][1])**2)
      end

      clusterer = c.build(data_set, n)

      clusterer.clusters.collect { |cluster|
        cluster.data_items.collect{ |i|
          vector[i[0]]
        }
      }
    end
  end

  def self.hulls(clusters)
    clusters_flatten = clusters.flatten(1)
    if clusters_flatten.empty?
      []
    else
      factory = Cartesian.preferred_factory

      multi_points = clusters.collect{ |cluster|
        factory.multi_point(cluster.collect{ |p|
          factory.point(p[1], p[0])
        })
      }

      clusters.each_with_index.map{ |cluster, i|
        unless cluster.empty?
          lat_min, lat_max = cluster.minmax_by{ |i| i[0] }.map{ |i| i[0] }
          lng_min, lng_max = cluster.minmax_by{ |i| i[1] }.map{ |i| i[1] }
          buffer = [[(lat_max - lat_min), (lng_max - lng_min)].min * 0.02, 1e-04].max
          hull(factory, cluster, multi_points[i], (i > 0 ? multi_points[0..i - 1] : []) + multi_points[i + 1..multi_points.length - 1], buffer)
        end
      }
    end
  end

  private

  def self.hull(factory, cluster, own_multi_point, other_multi_points, buffer)
    if cluster.empty?
      nil
    else
      borders = ConcaveHull.concave_hull(cluster.collect{ |p| [p[1], p[0]] }, 5)
      points = borders.collect{ |i|
        factory.point(i[0], i[1])
      }
      concave_hull = if points.size == 1
                       points[0]
      elsif points.size == 2
        factory.line_string(points)
      else
        factory.polygon(factory.linear_ring(points))
      end

      convex_hull = own_multi_point.convex_hull

      other_multi_points = factory.collection(other_multi_points)
      diff = convex_hull.difference(concave_hull)
      diff = [diff] if !defined? diff.to_a
      empty_part = factory.collection(diff.to_a.select{ |polygon|
        !polygon.crosses?(other_multi_points)
      })
      partial_concave_hull = concave_hull.union(empty_part)

      {'type' => 'Feature', 'properties' => {}, 'geometry' => RGeo::GeoJSON.encode(partial_concave_hull.buffer(buffer)) }.to_json
    end
  end
end
