# Copyright © Mapotempo, 2013-2016
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

require 'test_helper'
require 'case_insensitive_hash'

class CaseInsensitiveHashTest < ActiveSupport::TestCase
  test "should handle case insensitive key lookups" do
    hash = CaseInsensitiveHash.new

    hash["Route1"] = "value1"
    hash["ROUTE2"] = "value2"
    hash["route3"] = "value3"

    assert_equal "value1", hash["Route1"]
    assert_equal "value1", hash["route1"]
    assert_equal "value1", hash["ROUTE1"]

    assert_equal "value2", hash["ROUTE2"]
    assert_equal "value2", hash["route2"]
    assert_equal "value2", hash["Route2"]

    assert_equal "value3", hash["route3"]
    assert_equal "value3", hash["ROUTE3"]
    assert_equal "value3", hash["Route3"]

    assert hash.key?("Route1")
    assert hash.key?("route1")
    assert hash.key?("ROUTE1")

    keys = hash.keys
    assert_includes keys, "Route1"
    assert_includes keys, "ROUTE2"
    assert_includes keys, "route3"
  end

  test "should work with nested hashes" do
    outer_hash = CaseInsensitiveHash.new{ |h, k|
      h[k] = CaseInsensitiveHash.new{ |hh, kk|
        hh[kk] = CaseInsensitiveHash.new{ |hhh, kkk|
          hhh[kkk] = kkk == :visits ? [] : nil
        }
      }
    }

    outer_hash["Planning1"]["Route1"][:visits] = ["visit1"]
    outer_hash["PLANNING1"]["route1"][:visits] << "visit2"
    outer_hash["planning1"]["ROUTE1"][:visits] << "visit3"

    assert_equal ["visit1", "visit2", "visit3"], outer_hash["Planning1"]["Route1"][:visits]
    assert_equal ["visit1", "visit2", "visit3"], outer_hash["PLANNING1"]["route1"][:visits]
    assert_equal ["visit1", "visit2", "visit3"], outer_hash["planning1"]["ROUTE1"][:visits]
  end

  test "should handle nil keys" do
    hash = CaseInsensitiveHash.new
    hash[nil] = "nil_value"

    assert_equal "nil_value", hash[nil]
    assert hash.key?(nil)
  end

  test "should handle symbol keys" do
    hash = CaseInsensitiveHash.new
    hash[:symbol_key] = "symbol_value"

    assert_equal "symbol_value", hash[:symbol_key]
    assert_equal "symbol_value", hash["symbol_key"]
    assert_equal "symbol_value", hash["SYMBOL_KEY"]
    assert hash.key?(:symbol_key)
    assert hash.key?("symbol_key")
    assert hash.key?("SYMBOL_KEY")
  end

  test "should preserve original keys in iteration" do
    hash = CaseInsensitiveHash.new
    hash["OriginalKey"] = "value1"
    hash["ANOTHER_KEY"] = "value2"

    keys_collected = []
    hash.each_key do |key|
      keys_collected << key
    end

    assert_includes keys_collected, "OriginalKey"
    assert_includes keys_collected, "ANOTHER_KEY"
  end

  test "should handle empty hash" do
    hash = CaseInsensitiveHash.new

    assert hash.empty?
    assert_equal 0, hash.size
    assert_equal [], hash.keys
  end

  test "should handle clear operation" do
    hash = CaseInsensitiveHash.new
    hash["key1"] = "value1"
    hash["KEY2"] = "value2"

    assert_equal 2, hash.size
    hash.clear
    assert hash.empty?
    assert_equal 0, hash.size
  end

  test "should handle default proc" do
    hash = CaseInsensitiveHash.new{ |h, k| h[k] = "default_#{k}" }

    assert_equal "default_test", hash["TEST"]
    assert_equal "default_test", hash["test"]
    assert_equal "default_test", hash["Test"]
  end

  test "should handle delete operation" do
    hash = CaseInsensitiveHash.new
    hash["Key1"] = "value1"
    hash["KEY2"] = "value2"

    assert_equal "value1", hash.delete("key1")
    assert_equal 1, hash.size
    assert hash.key?("KEY2")
    assert_not hash.key?("Key1")
  end
end
