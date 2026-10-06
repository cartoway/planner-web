# frozen_string_literal: true

module Operations
  class TransmitRoutes
    def self.call(operation:, routes:)
      emailed = routes.count { |operation_route| send_email(operation_route) }
      { emailed: emailed, sms: send_sms(operation, routes) }
    end

    def self.send_sms(operation, routes)
      return 0 unless operation.customer.enable_sms

      SendDriverSms.call(operation: operation, routes: routes)
    rescue ArgumentError
      0
    end

    # Returns whether the mail was queued/delivered (used as a count predicate).
    # rubocop:disable Naming/PredicateMethod
    def self.send_email(operation_route)
      email = operation_route.driver_email
      return false if email.blank?

      customer = operation_route.operation.customer
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
