module ImportExportCustomer
  extend ActiveSupport::Concern

  def self.export(customer)
    Marshal.dump(
      Customer.includes(
        [vehicles: :vehicle_usages],
        [destinations: :visits],
        [plannings: [routes: :stops]],
        [zonings: :zones],
        [stores: :store_reloads],
        :deliverable_units,
        :vehicle_usage_sets,
        :tags,
        :users
      ).find(customer.id)
    )
  end

  def self.import(string_customer, options)
    customer = Marshal.load(string_customer)
    customer = customer.duplicate
    self.assign_miscellaneous_attributes(customer, options)
    customer.save! validate: Planner::Application.config.validate_during_duplication
    customer
  end

  def self.assign_miscellaneous_attributes(customer, options)
    customer.assign_attributes({
      profile_id: options[:profile_id],
      router_id: options[:router_id],
      router_options: {}
    })
    customer.vehicles.where.not(router_id: nil).update_all({router_id: options[:router_id], router_options: {}})
    customer.users.where.not(layer_id: nil).update_all(layer_id: options[:layer_id])
  end
end
