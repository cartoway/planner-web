class UserMailer < ApplicationMailer

  attr_accessor :links

  around_action :catch_smtp_error

  def password_message(user, locale)
    I18n.with_locale(locale) do
      @user = user
      @reseller = user.customer.reseller
      @name, @application_name = names(user) # To deprecate
      @title = t('user_mailer.password.title')
      @confirmation_link = password_user_url(user, token: user.confirmation_token, host: user.customer.reseller.url_protocol + '://' + user.customer.reseller.host)
      @subscription_duration = user.customer.end_subscription && (user.customer.end_subscription - Date.today).to_i > 1 ? (user.customer.end_subscription - Date.today).to_i : nil
      @home_link = user.customer.reseller.url_protocol + '://' + user.customer.reseller.host
      @template = 'password'

      mail to: user.email, from: "#{@user.customer.reseller.name} <#{Rails.application.config.default_from_mail}>", subject: t('user_mailer.password.subject', name: @user.customer.reseller.name) do |format|
        format.html { render 'user_mailer/password', locals: { user: user } }
      end
    end
  end

  def connection_message(user, locale)
    I18n.with_locale(locale) do
      @user = user
      @reseller = user.customer.reseller
      @name, @application_name = names(user) # To deprecate
      @title = t('user_mailer.connection.title')
      @home_link = user.customer.reseller.url_protocol + '://' + user.customer.reseller.host
      @template = 'connection'

      mail to: user.email, from: "#{@user.customer.reseller.name} <#{Rails.application.config.default_from_mail}>", subject: t('user_mailer.connection.subject', name: @user.customer.reseller.name) do |format|
        format.html { render 'user_mailer/connection', locals: { user: user } }
      end
    end
  end

  def accompanying_message(user, locale)
    I18n.with_locale(locale) do
      @user = user
      @reseller = user.customer.reseller
      @name, @application_name = names(user) # To deprecate
      @template = 'accompanying'
      @parameters = links_parameters('accompanying_message', locale)
      @title = t('user_mailer.accompanying.title')
      @home_link = user.customer.reseller.url_protocol + '://' + user.customer.reseller.host
      @contact_url = contact_url(user, locale)

      mail to: user.email, from: "#{@user.customer.reseller.name} <#{Rails.application.config.default_from_mail}>", subject: t('user_mailer.accompanying.title') do |format|
        format.html { render 'user_mailer/accompanying', locals: { user: user } }
      end
    end
  end

  def subscribe_message(user, locale)
    I18n.with_locale(locale) do
      @user = user
      @reseller = user.customer.reseller
      @name, @application_name = names(user) # To deprecate
      @template = 'subscribe'
      @parameters = links_parameters('subscribe_message', locale)
      @title = t('user_mailer.subscribe.title')
      @home_link = user.customer.reseller.url_protocol + '://' + user.customer.reseller.host

      mail to: user.email, from: "#{@user.customer.reseller.name} <#{Rails.application.config.default_from_mail}>", subject: t('user_mailer.subscribe.title') do |format|
        format.html { render 'user_mailer/subscribe', locals: { user: user } }
      end
    end
  end

  def automation_dispatcher(user, locale, template = 'accompanying_team', with_links = false)
    I18n.with_locale(locale) do
      @user = user
      @reseller = user.customer.reseller
      @name, @application_name = names(user) # To deprecate
      @home_link = user.customer.reseller.url_protocol + '://' + user.customer.reseller.host
      @template = template
      @help_url = user.customer.reseller.help_url.sub('{LG}', locale.to_s)
      @contact_url = contact_url(user, locale)
      @with_links = with_links
      @parameters = links_parameters(template, locale)

      mail to: user.email, from: "#{@user.customer.reseller.name} <#{Rails.application.config.default_from_mail}>", subject: t("user_mailer.#{template}.panels_header") do |format|
        format.html { render 'user_mailer/documentation_base', locals: { user: user } }
      end
    end
  end

  def send_fleet_drivers(user, locale, drivers, current_admin = nil)
    I18n.with_locale(locale) do
      @user = user
      @reseller = user.customer.reseller
      @name, @application_name = names(user) # To deprecate
      @template = 'fleet_drivers'
      [user.email, current_admin && current_admin.email].compact.each do |to|
        mail to: to, subject: I18n.t('user_mailer.fleet_drivers.subject') do |format|
          format.html { render 'user_mailer/fleet_drivers', locals: { user: user, drivers: drivers } }
        end
      end
    end
  end

  private

  def catch_smtp_error
    begin
      yield
    rescue Net::SMTPFatalError => e
      if e.message.include?('User unknown in virtual mailbox table')
        puts e.inspect
      else
        raise
      end
    end
  end

  def links_parameters(name, locale = :fr)
    Rails.application.config.automation[:parameters][name.to_sym][locale.to_sym] || Rails.application.config.automation[:parameters][name.to_sym][:en]
  end

  def contact_url(user, locale)
    url = user.customer.reseller.contact_url
    url.sub '{LG}', locale.to_s
  end

  def names(user)
    name = user.customer.reseller.name # To deprecate
    application_name = user.customer.reseller.application_name || name

    [name, application_name]
  end
end
