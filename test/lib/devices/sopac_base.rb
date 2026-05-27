# frozen_string_literal: true

module SopacBase
  def add_sopac_credentials(customer)
    customer.devices = {
      sopac: {
        enable: 'true',
        username: 'sebastien.rigolat@example.com',
        password: '2018',
        queue_prefix: '/SOPAC/CARTOWAY'
      }
    }
    customer.save!
    customer.vehicles.first.update!(devices: { sopac_ids: ['2000352F'] })
    customer
  end
end
