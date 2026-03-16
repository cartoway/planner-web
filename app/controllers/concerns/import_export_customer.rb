module ImportExportCustomer
  extend ActiveSupport::Concern

  def self.export(customer)
    customer_data = Customer.for_duplication.find(customer.id)
    Marshal.dump(customer_data)
  end

  def self.import(customer_data_file, options)
    customer = Marshal.load(customer_data_file.read)
    self.assign_miscellaneous_attributes(customer, options)
    customer = customer.duplicate
    customer.save! validate: Planner::Application.config.validate_during_duplication
    customer
  end

  def self.assign_miscellaneous_attributes(customer, options)
    customer.assign_attributes({
      profile_id: options[:profile_id],
      reseller_id: options[:reseller_id],
      router_id: options[:router_id],
      router_options: {}
    }.compact)
    customer.vehicles.select{ |vehicle| vehicle.router_id.present? }
            .each{ |vehicle| vehicle.assign_attributes(router_id: options[:router_id], router_options: {}) }
    customer.users.select{ |user| user.layer_id.present? }
            .each{ |user| user.assign_attributes(layer_id: options[:layer_id]) }
  end
end
