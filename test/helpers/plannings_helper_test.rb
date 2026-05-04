# frozen_string_literal: true

require 'test_helper'

class PlanningsHelperTest < ActionView::TestCase
  include PlanningsHelper

  test 'planning_summary includes planning_id and routes for sidebar / stop popover data' do
    planning = plannings(:planning_one)
    s = planning_summary(planning)
    assert_equal planning.id, s[:planning_id]
    assert s.key?(:routes)
    assert s[:routes].is_a?(Array)
  end
end
