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

class V2CustomersFormAccordionHeaderTest < ActionView::TestCase
  test 'renders a collapse button header instead of a hyperlink' do
    render partial: 'v2/customers/form_accordion_header',
           locals: { target: 'collapsePrint', title: 'Print' }

    assert_select 'a[href="#collapsePrint"]', count: 0
    assert_select 'button.customer-form-accordion-toggle.v2-collapse-toggle[type="button"][data-bs-target="#collapsePrint"][aria-controls="collapsePrint"]', text: /Print/
    assert_select 'button.customer-form-accordion-toggle .accordion-chevron', count: 1
  end
end
