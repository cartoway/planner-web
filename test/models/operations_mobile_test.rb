# frozen_string_literal: true

# Copyright © Cartoway, 2026
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

require 'test_helper'

class OperationsMobileTest < ActiveSupport::TestCase
  test 'capability_three_way_split groups usable visible and none' do
    document = {
      'version' => 1,
      'capabilities' => {
        'routes.read_all' => 'visible',
        'stops.proofs' => 'none',
        'routes.start' => 'usable'
      }
    }

    usable, visible, none = OperationsMobile.capability_three_way_split(document)
    assert_includes usable, 'routes.start'
    assert_includes visible, 'routes.read_all'
    assert_includes none, 'stops.proofs'
    refute_includes usable + visible + none, 'routes.read_assigned'
    assert_equal OperationsMobile::CAPABILITIES.sort, (usable + visible + none).sort
  end

  test 'read implies routes.read_assigned when access_usable' do
    document = OperationsMobile.driver_default
    caps = OperationsMobile.read(document, access_usable: true)['capabilities']

    assert_equal 'usable', caps['routes.read_assigned']
    refute_includes caps.keys, 'catalog.read'
  end

  test 'from_form builds capabilities without access key' do
    doc = OperationsMobile.from_form(usable: %w[stops.proofs], visible: %w[routes.read_all])

    assert_equal 1, doc['version']
    refute doc.key?('access')
    assert_equal 'usable', doc.dig('capabilities', 'stops.proofs')
    assert_equal 'visible', doc.dig('capabilities', 'routes.read_all')
    assert_equal 'none', doc.dig('capabilities', 'routes.start')
  end

  test 'coerce drops deprecated and implied capability keys and access' do
    coerced = OperationsMobile.coerce(
      'version' => 1,
      'access' => 'usable',
      'capabilities' => {
        'routes.read_assigned' => 'none',
        'catalog.read' => 'usable',
        'stops.proofs' => 'usable'
      }
    )

    refute coerced.key?('access')
    assert_equal({ 'stops.proofs' => 'usable' }, coerced['capabilities'])
  end
end
