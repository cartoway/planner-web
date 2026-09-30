# frozen_string_literal: true

class BackfillOperationsFromPastPlannings < ActiveRecord::Migration[6.1]
  def up
    Operations::BackfillFromPastPlannings.call
  end

  def down
    Operations::BackfillFromPastPlannings.revert
  end
end
