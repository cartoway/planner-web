class RouteMailer < ApplicationMailer

  def send_kmz_route(user, locale, vehicle, route, filename, attachment)
    I18n.with_locale(locale) do
      @user = user
      @customer = user.customer
      @name = user.customer.reseller.name # To deprecate
      @title = I18n.t('route_mailer.send_kmz_route.title')
      attachments[filename] = { transfer_encoding: :binary, content: attachment.force_encoding('BINARY') }
      mail to: vehicle.contact_email, subject: "[#{user.customer.reseller.name}] #{filename}" do |format|
        format.html { render 'route_mailer/send_kmz_route', locals: { vehicle: vehicle, route: route } }
      end
    end
  end

  def send_computed_ics_route(user, locale, email, vehicles)
    I18n.with_locale(locale) do
      @user = user
      @customer = user.customer
      @name = user.customer.reseller.name # To deprecate
      @title = I18n.t('route_mailer.send_computed_ics_route.title')
      mail to: email, subject: "[#{user.customer.reseller.name}] Export Planning iCalendar" do |format|
        format.html { render 'route_mailer/send_computed_ics_route', locals: { user: user, infos: vehicles } }
      end
    end
  end

  def send_driver_route(customer, locale, email, route)
    @customer = customer
    I18n.with_locale(locale) do
      @title = I18n.t('route_mailer.send_driver_route.title')
      mail to: email, subject: "[#{route.vehicle_usage.vehicle.name}] #{t('route_mailer.send_driver_route.subject')}" do |format|
        format.html { render 'route_mailer/send_driver_route', locals: { customer: customer, route: route } }
      end
    end
  end
end
