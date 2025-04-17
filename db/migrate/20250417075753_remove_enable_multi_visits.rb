class RemoveEnableMultiVisits < ActiveRecord::Migration[6.1]
  def changes
    Customer.where(enable_multi_visits: false).find_each { |customer|
      customer.destinations.find_each { |destination|
        destination.visits.each { |visit|
          visit.ref ||= destination.ref
          visit.tags |= destination.tags
          visit.internal_skip = true
        }
        destination.ref = nil
        destination.tag_ids = []
        # Don't load all plans to update them...
        destination.internal_skip = true
        destination.save!
      }
    }
    remove_column :customers, :enable_multi_visits
  end
end
