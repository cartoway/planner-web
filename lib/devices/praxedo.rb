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

require 'json'

class Praxedo < DeviceBase

  def definition
    {
      device: 'praxedo',
      label: 'Praxedo',
      label_small: 'Praxedo',
      route_operations: [:send, :clear],
      has_sync: false,
      help: true,
      forms: {
        settings: {
          login: :text,
          password: :password,
          code_inter_start: :text,
          code_inter_stop: :text,
          code_mat: :text,
          code_route: :text
        },
        vehicle: {
          praxedo_agent_id: :text
        },
      }
    }
  end

  # FIXME: not used for now
  # def savon_client_geolocalisation(customer)
  #   Savon.client(wsdl: api_url + '2006_09_25/GeolocalisationDataService?wsdl', soap_version: 1, open_timeout: 60, read_timeout: 60) do
  #     log true
  #     pretty_print_xml true
  #     convert_request_keys_to :none
  #   end
  # end

  def savon_client_events(customer)
    Savon.client({basic_auth: [customer.devices[:praxedo][:login], customer.devices[:praxedo][:password]], wsdl: api_url + 'cxf/v6/BusinessEventManager?wsdl', env_namespace: :soapenv, soap_version: 2, multipart: true, proxy: ENV['http_proxy']}.compact) do
      log false
      pretty_print_xml true
      convert_request_keys_to :none
    end
  end

  def check_auth(params)
    client = Savon.client({basic_auth: [params[:login], params[:password]], wsdl: api_url + 'cxf/v6/BusinessEventManager?wsdl', env_namespace: :soapenv, soap_version: 2, multipart: true, proxy: ENV['http_proxy']}.compact) do
      log false
      pretty_print_xml true
      convert_request_keys_to :none
    end

    get(client, :get_events, {
      requestedEvents: ['']
    })
  end

  def format_position(customer, route, position, order_id, options = {})
    {
      coreData: {
        anomaly: false,
        creationDate: Time.now.strftime('%FT%T.%L%:z'),
        description: '',
        referentialData: {
          '@xsi:type' => 'tns:externalReferentialData',
          customerName: position.name,
          location: {
            address: [position.street, options[:stop] && position.detail].compact.join(' '),
            city: position.city,
            contact: options[:stop] && position.phone_number,
            name: position.name,
            zipCode: position.postalcode,
            description: options[:description],
            geolocation: {
              latitude: position.lat,
              longitude: position.lng
            }
          }.compact,
          equipmentName: options[:equipment_name]
        }.compact
      },
      id: encode_uid(options[:description], order_id, planning_date(route.planning)),
      qualificationData: {
        type: {
          id: options[:code_type_inter],
          duration: options[:duration] ? options[:duration] / 60 : 0 # unit: min
        },
        instructions: options[:instructions].map { |instruction|
          {
            '@xsi:type' => 'tns:reportField',
            id: instruction[:id],
            value: instruction[:value]
          }.compact
        }.compact
      }.select { |_, v| v.present? },
      schedulingData: {
        agentId: {
          '@xsi:type' => 'tns:externalEntityId',
          id: route.vehicle_usage.vehicle.devices[:praxedo_agent_id]
        },
        appointmentDate: (p_time(route, options[:appointment_time]).strftime('%FT%T.%L%:z') if options[:appointment_time]),
        schedulingDate: (p_time(route, options[:schedule_time]).strftime('%FT%T.%L%:z') if options[:schedule_time]),
        useSchedulingHour: true
      }.compact
    }.compact
  end

  def send_route(customer, route, _options = {})
    events = []
    code_route_id = encode_uid(route.ref.to_s, route.id, planning_date(route.planning))

    start = route.vehicle_usage.default_store_start
    if start && !start.lat.nil? && !start.lng.nil?
      order_id = "-1#{route.id}"
      description = I18n.transliterate(start.name) || "#{start.lat} #{start.lng}"
      events << format_position(customer, route, start, order_id, appointment_time: route.start, schedule_time: route.start, duration: route.vehicle_usage.default_service_time_start, description: description, code_type_inter: customer.devices[:praxedo][:code_inter_start], instructions: [{id: customer.devices[:praxedo][:code_route], value: code_route_id}])
    end

    route.stops.select { |s| s.active && s.position? && !s.is_a?(StopRest) }.map do |stop|
      order_id = stop.is_a?(StopVisit) ? "v#{stop.visit_id}" : "r#{stop.id}#{route.id}"
      description =
      [
        stop.comment,
        stop.time_window_start_1 || stop.time_window_end_1 ? (stop.time_window_start_1 ? stop.time_window_start_1_time + number_of_days(stop.time_window_start_1) : '') + (stop.time_window_start_1 && stop.time_window_end_1 ? '-' : '') + (stop.time_window_end_1 ? (stop.time_window_end_1_time + number_of_days(stop.time_window_end_1) || '') : '') : nil,
        stop.time_window_start_2 || stop.time_window_end_2 ? (stop.time_window_start_2 ? stop.time_window_start_2_time + number_of_days(stop.time_window_start_2) : '') + (stop.time_window_start_2 && stop.time_window_end_2 ? '-' : '') + (stop.time_window_end_2 ? (stop.time_window_end_2_time + number_of_days(stop.time_window_end_2) || '') : '') : nil,
      ].compact.join(' ').strip
      code_type_inter = stop.visit.tags.map(&:label).map { |label| label.split('praxedo:')[1] }.compact.first
      events << format_position(customer, route, stop, order_id, stop: true, appointment_time: stop.time_window_start_1 || stop.time_window_end_1 || stop.time_window_start_2 || stop.time_window_end_2 || stop.time, schedule_time: stop.time, duration: stop.duration, description: description, code_type_inter: code_type_inter, instructions: [{id: customer.devices[:praxedo][:code_route], value: code_route_id}, {id: customer.devices[:praxedo][:code_mat], value: stop.visit.ref}], equipment_name: stop.visit.destination.ref) # Destination ref is used as equipmentName, best possible choice
    end

    stop = route.vehicle_usage.default_store_stop
    if stop && !stop.lat.nil? && !stop.lng.nil?
      order_id = "-2#{route.id}"
      description = I18n.transliterate(stop.name) || "#{start.lat} #{start.lng}"
      events << format_position(customer, route, stop, order_id, appointment_time: route.end, schedule_time: route.end, duration: route.vehicle_usage.default_service_time_end, description: description, code_type_inter: customer.devices[:praxedo][:code_inter_stop], instructions: [{id: customer.devices[:praxedo][:code_route], value: code_route_id}])
    end

    get(savon_client_events(customer), :create_events, events: events)
  end

  def fetch_stops(customer, date, _planning)
    orders = []

    begin
      message = {
        request: {
          agentIdConstraint: customer.vehicles.map { |v| v.devices[:praxedo_agent_id] }.compact,
          dateConstraints: {
            name: 'completionDate', # available types: creationDate, appointmentDate, schedulingDate, completionDate
            dateRange: [date.strftime('%FT%T.%L%:z'), (date + 2.day).strftime('%FT%T.%L%:z')] # FIXME: change 2 days
          },
          statusConstraint: 'COMPLETED'
        },
        firstResultIndex: orders.size,
        batchSize: 50, # return 50 paginated results,
        options: [
          {
            key: 'businessEvent.populate.coreData'
          },
          {
            '@xsi:type' => 'tns:wsValuedEntry',
            key: 'businessEvent.populate.coreData.referentialData',
            value: 'external'
          },
          {
            key: 'businessEvent.populate.qualificationData'
          },
          {
            key: 'businessEvent.populate.schedulingData'
          },
          {
            key: 'businessEvent.populate.completionData.fields'
          },
          {
            key: 'businessEvent.populate.completionData.items'
          },
          {
            key: 'businessEvent.populate.completionData.lifeCycleDate'
          }
        ]
      }

      response = get(savon_client_events(customer), :search_events, message)

      response = response[:entities]
      if !response.is_a?(Array)
        orders += [response]
      else
        orders += response
      end
    end while (response && !response.empty?)

    orders.compact.map { |intervention|
      if intervention[:completion_data] && intervention[:completion_data][:fields]
        quantities = []
        intervention[:completion_data][:fields].map do |field|
          quantities << {
            label: field[:id],
            quantity: field[:value]
          }
        end

        {
          order_id: decode_uid(intervention[:id]),
          quantities: quantities,
          update_quantities: true
          # Status are not sync (using TomTom's statuses)
        }
      end
    }.compact
  end

  # FIXME: not used for now
  # def vehicle_pos(customer)
  #   objects = get(savon_client_geolocalisation(customer), :get_last_position_for_agents, { authenticationString: "#{customer.devices[:praxedo][:login]}|#{customer.devices[:praxedo][:password]}" })
  #   objects.collect do |object|
  #     {
  #         #praxedo_agent_id:
  #         #device_name:
  #         lat: object[:position][0][0],
  #         lng: object[:position][0][1]
  #     }
  #   end if objects
  # end

  def clear_route(customer, route)
    events = {
      eventsToDelete: []
    }
    start = route.vehicle_usage.default_store_start
    if start && !start.lat.nil? && !start.lng.nil?
      order_id = "-1#{route.id}"
      description = I18n.transliterate(start.name) || "#{start.lat} #{start.lng}"
      events[:eventsToDelete] << encode_uid(description, order_id, planning_date(route.planning))
    end

    route.stops.select { |s| s.active && s.position? && !s.is_a?(StopRest) }.map do |stop|
      order_id = stop.is_a?(StopVisit) ? "v#{stop.visit_id}" : "r#{stop.id}#{route.id}"
      description = [
        stop.comment,
        stop.time_window_start_1 || stop.time_window_end_1 ? (stop.time_window_start_1 ? stop.time_window_start_1_time + number_of_days(stop.time_window_start_1) : '') + (stop.time_window_start_1 && stop.time_window_end_1 ? '-' : '') + (stop.time_window_end_1 ? (stop.time_window_end_1_time + number_of_days(stop.time_window_end_1) || '') : '') : nil,
        stop.time_window_start_2 || stop.time_window_end_2 ? (stop.time_window_start_2 ? stop.time_window_start_2_time + number_of_days(stop.time_window_start_2) : '') + (stop.time_window_start_2 && stop.time_window_end_2 ? '-' : '') + (stop.time_window_end_2 ? (stop.time_window_end_2_time + number_of_days(stop.time_window_end_2) || '') : '') : nil,
      ].compact.join(' ').strip
      events[:eventsToDelete] << encode_uid(description, order_id, planning_date(route.planning))
    end

    stop = route.vehicle_usage.default_store_stop
    if stop && !stop.lat.nil? && !stop.lng.nil?
      order_id = "-2#{route.id}"
      description = I18n.transliterate(stop.name.to_s) || "#{start.lat} #{start.lng}"
      events[:eventsToDelete] << encode_uid(description, order_id, planning_date(route.planning))
    end
    get(savon_client_events(customer), :delete_events, events).to_xml
  end

  private

  def get(client, operation, message = {})
    response = client.call(operation, { message: message })

    response_body = if operation == :create_events
                      response.body[:create_events_response][:return]
                    elsif operation == :get_events
                      response.body[:get_events_response][:return]
                    else
                      response.body.first[1][:return]
                    end

    result_code = response_body[:result_code]
    if %w(0 200).include?(result_code)
      if response_body[:results]
        return response_body[:results]
      else
        response_body
      end
    else
      raise DeviceServiceError.new("Praxedo: #{result_code}, #{response_body[:message]}")
    end

  rescue Savon::SOAPFault => error
    if error.http.code == 500 && error.to_hash[:fault][:detail] && error.to_hash[:fault][:detail][:ws_fault][:result_code] == '10'
      raise DeviceServiceError.new('Praxedo: ' + I18n.t('errors.praxedo.invalid_account'))
    else
      Rails.logger.info error
      fault_code = error.to_hash[:fault][:code][:value]
      fault_reason = error.to_hash[:fault][:reason][:text]
      raise DeviceServiceError.new("Praxedo: #{fault_code}, #{fault_reason}")
    end
  rescue Savon::HTTPError => error
    Rails.logger.info error.http.code
    raise error
  end
end
