# Copyright © Mapotempo, 2017
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#

require 'net/ftp'
require 'tempfile'

class Notico < DeviceBase
  def definition
    {
      device: 'notico',
      label: 'Notico Deliv',
      label_small: 'Notico',
      route_operations: [:send, :clear],
      has_sync: false,
      help: true,
      forms: {
        settings: {
          ftp_url: :text,
          ftp_path: :text,
          username: :text,
          password: :password
        },
        vehicle: {
          agent_id: :text
        },
      }
    }
  end

  def check_auth(credentials)
    get(credentials)
  end

  def send_route(customer, route, options = {})
    interventions = {}

    route.stops.select { |s| s.active && s.position? && !s.is_a?(StopRest) }.map do |stop|
      quantities = customer.enable_orders ? (stop.order ? stop.order.products.collect(&:code).join(',') : '') : customer.deliverable_units.map { |du| stop.visit.default_quantities[du.id] && du.label && "#{number_with_precision(stop.visit.default_quantities[du.id], strip_insignificant_zeros: true)} #{du.label}" }.compact.join(' ')
      labels = stop.visit.destination.tags.pluck(:label).join(', ')
      if interventions[stop.visit.destination.ref] && interventions[stop.visit.destination.ref][:tourId] == stop.route_id
        interventions[stop.visit.destination.ref][:items] << {
          col_1: stop.visit.ref,
          col_2: stop.comment || '',
          col_3: quantities,
          col_4: labels
        }
      else
        interventions[stop.visit.destination.ref] = {
          interId: stop.base_id,
          contractId: stop.visit.destination.ref,
          tourId: stop.route_id,
          agentId: route.vehicle_usage.vehicle.devices[:agent_id],

          name: stop.name,
          language: I18n.locale.to_s.upcase,
          address: [stop.street, stop.detail].compact.join(' '),
          zip_code: stop.postalcode,
          city: stop.city,
          country: stop.country || customer.default_country,
          phone: stop.phone_number || '',

          dt_firststart: p_time(route, stop.time_window_start_1 || stop.time_window_start_2 || stop.time).strftime('%F %H:%M'),
          dt_firstend: p_time(route, stop.time_window_end_1 || stop.time_window_end_2 || (stop.duration ? stop.time + stop.duration.seconds : stop.time)).strftime('%F %H:%M'),

          items: [{
                    col_1: stop.visit.ref,
                    col_2: stop.comment || '',
                    col_3: quantities,
                    col_4: labels
                  }]
        }
      end
    end

    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.interventions {
        interventions.each do |contractId, data|
          xml.intervention(contractId: contractId, interId: data[:interId], tourId: data[:tourId], agentId: data[:agentId], action: options[:delete] ? 'delete' : nil) {
            unless options[:delete]
              xml.customer {
                xml.name data[:name]
                xml.language data[:language]
                xml.address data[:address]
                xml.zip_code data[:zip_code]
                xml.city data[:city]
                xml.country data[:country]
                xml.phone data[:phone]
              }

              xml.dt_firststart data[:dt_firststart]
              xml.dt_firstend data[:dt_firstend]

              xml.todo {
                data[:items].map { |item|
                  xml.item {
                    xml.col_1 { xml.cdata(item[:col_1]) }
                    xml.col_2 { xml.cdata(item[:col_2]) }
                    xml.col_3 { xml.cdata(item[:col_3]) }
                    xml.col_4 { xml.cdata(item[:col_4]) }
                  }
                }
              }

              xml.signature 'oui'
            end
          }
        end
      }
    end

    credentials = customer.devices[:notico]
    get(credentials, {
        filename: "flux_livraisons#{Time.zone.now.strftime('%Y%m%d%H%M%S')}.xml",
        xml_content: builder.to_xml
    })
  end

  def clear_route(customer, route)
    send_route(customer, route, delete: true)
  end

  private

  def get(credentials, message = {})
    ftp = nil

    begin
      Timeout.timeout(10) do
        ftp = Net::FTP.new(credentials[:ftp_url])
        ftp.passive = true
        ftp.login(credentials[:username], credentials[:password])

        if message[:filename] && message[:xml_content]
          ftp.chdir(credentials[:ftp_path])

          temp_file = Tempfile.new(message[:filename])
          temp_file.write(message[:xml_content])
          temp_file.close

          ftp.putbinaryfile(temp_file, message[:filename])

          temp_file.unlink
        end

        ftp.close
      end
    rescue Timeout::Error
      raise DeviceServiceError.new("Notico: #{I18n.t('errors.notico.invalid_server')}")
    rescue
      raise DeviceServiceError.new("Notico: #{ftp ? ftp.last_response : I18n.t('errors.notico.invalid_server')}")
    end
  end
end
