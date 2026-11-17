# frozen_string_literal: true

# Copyright © Cartoway
require 'test_helper'

class IndexHelperTest < ActionView::TestCase
  test 'customer_summary preloads routes on latest plannings' do
    @customer = customers(:customer_one)
    summary = customer_summary
    planning = summary[:plannings][:latest].first
    assert planning
    assert planning.association(:routes).loaded?
    assert_equal @customer.plannings_count, summary[:plannings][:count]
  end
end
