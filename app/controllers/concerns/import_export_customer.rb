module ImportExportCustomer
  extend ActiveSupport::Concern

  def self.export(customer)
    customer_data = Customer.for_duplication.find(customer.id)
    Marshal.dump(customer_data)
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
