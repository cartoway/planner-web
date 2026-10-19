# frozen_string_literal: true

module Operations
  class TransmitRoutes
    # channel: global 'email'|'sms' (legacy). row_channels: { planning_route_id => 'email'|'sms'|'none' }.
    def self.call(operation:, routes:, channel: nil, row_channels: nil)
      return { emailed: 0, sms: 0 } unless operation.open?

      if row_channels.present?
        email_routes = []
        sms_routes = []
        routes.each do |operation_route|
          ch = row_channel_for(operation_route, row_channels, channel)
          case ch
          when 'email' then email_routes << operation_route
          when 'sms' then sms_routes << operation_route
          end
        end
        return {
          emailed: email_routes.count { |operation_route| send_email(operation_route) },
          sms: sms_routes.empty? ? 0 : send_sms(operation, sms_routes)
        }
      end

      case channel.to_s
      when 'email'
        { emailed: routes.count { |operation_route| send_email(operation_route) }, sms: 0 }
      when 'sms'
        { emailed: 0, sms: send_sms(operation, routes) }
      else
        emailed = routes.count { |operation_route| send_email(operation_route) }
        { emailed: emailed, sms: send_sms(operation, routes) }
      end
    end

    def self.row_channel_for(operation_route, row_channels, fallback = nil)
      rid = operation_route.route_id
      (row_channels[rid] || row_channels[rid.to_s] || fallback).to_s
    end
    private_class_method :row_channel_for

    def self.send_sms(operation, routes)
      return 0 unless operation.open?
      return 0 unless operation.customer.enable_sms_driver

      SendDriverSms.call(operation: operation, routes: routes)
    rescue ArgumentError
      0
    end

    # Returns whether the mail was queued/delivered (used as a count predicate).
    # rubocop:disable Naming/PredicateMethod
    def self.send_email(operation_route)
      operation = operation_route.operation
      return false unless operation.open?

      customer = operation.customer
      return false unless customer.enable_email_driver

      email = operation_route.driver_email
      return false if email.blank?

      if Planner::Application.config.delayed_job_use
        RouteMailer.delay.send_operation_route(customer, I18n.locale, email, operation_route)
      else
        RouteMailer.send_operation_route(customer, I18n.locale, email, operation_route).deliver_now
      end
      operation_route.mark_sent!('email')
      true
    end
    # rubocop:enable Naming/PredicateMethod

    private_class_method :send_sms
  end
end
