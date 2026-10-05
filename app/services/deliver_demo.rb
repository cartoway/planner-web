# frozen_string_literal: true

require 'value_to_boolean'

module DeliverDemo
  # Slightly slower than a pure stress test so the operation page stays usable.
  DELAY = 1.seconds

  module_function

  def enabled?(customer)
    enableds = customer&.device&.enableds
    return false unless enableds&.key?(:deliver)

    ValueToBoolean.value_to_boolean(customer.devices.dig(:deliver, :demo))
  end
end
