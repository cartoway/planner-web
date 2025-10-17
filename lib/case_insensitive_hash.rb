# Copyright © Cartoway, 2025
#
# This file is part of Cartoway Planner.
#
# Cartoway Planner is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoway Planner. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#

class CaseInsensitiveHash < ActiveSupport::HashWithIndifferentAccess
  def initialize(constructor = nil)
    @key_map = {}
    if constructor.nil?
      super()
    elsif constructor.respond_to?(:to_hash)
      super()
      update(constructor)

      hash = constructor.is_a?(Hash) ? constructor : constructor.to_hash
      self.default = hash.default if hash.default
      self.default_proc = hash.default_proc if hash.default_proc
      self
    else
      super
    end
  end

  def self.[](*args)
    hash = new
    Hash[*args].each { |key, value| hash[key] = value }
    hash
  end

  def [](key)
    normalized_key = normalize_key(key)
    if key?(normalized_key) || !default_proc
      super(normalized_key)
    else
      default_proc.call(self, normalized_key)
    end
  end

  def []=(key, value)
    @key_map[normalize_key(key)] = key
    super(normalize_key(key), value)
  end

  def key?(key)
    super(normalize_key(key))
  end

  def delete(key)
    @key_map.delete(normalize_key(key))
    super(normalize_key(key))
  end

  def keys
    @key_map.values
  end

  def each
    @key_map.each_value do |original_key|
      yield(original_key, self[original_key])
    end
  end

  def each_key
    @key_map.each_value do |original_key|
      yield(original_key)
    end
  end

  def each_value
    @key_map.each_value do |original_key|
      yield(self[original_key])
    end
  end

  def select
    result = CaseInsensitiveHash.new
    @key_map.each_value do |original_key|
      value = self[original_key]
      if yield(original_key, value)
        result[original_key] = value
      end
    end
    result
  end

  def empty?
    @key_map.empty?
  end

  def size
    @key_map.size
  end

  def clear
    @key_map.clear
    super
  end

  private

  def normalize_key(key)
    return key if key.nil?

    key.to_s.strip.downcase
  end
end
