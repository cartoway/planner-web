namespace :mail do
  desc 'Mail manager'

  desc 'Send automation mails at defined time'
  task automation: :environment do
    request = User.joins(:customer).where('customers.test' => true, 'customers.end_subscription' => Time.zone.today + 1.days) | User.where(created_at: (Time.zone.today - 9.days)..Time.zone.today).where.not(customer_id: nil)

    users = request.select { |user|
      /https?:\/\/cartoroute.com\/[^\/]+\/help-center/.match(user.customer.reseller.help_url) && /https?:\/\/cartoroute.com\/[^\/]+\/contact-support/.match(user.customer.reseller.contact_url)
    }
    users.each do |user|
      begin
        date = user.created_at.to_date
        locale = user.locale ? user.locale.to_sym : I18n.locale

        case Time.zone.today
          when date + 1.days
            UserMailer.automation_dispatcher(user, locale, 'accompanying_team').deliver_now # 3
          when date + 2.days
            UserMailer.automation_dispatcher(user, locale, 'features', true).deliver_now # 4
          when date + 3.days
            UserMailer.automation_dispatcher(user, locale, 'advanced_options', true).deliver_now # 5
          when date + 9.days
            UserMailer.accompanying_message(user, locale).deliver_now
          when user.customer.end_subscription && user.customer.end_subscription.to_date - 1.days
            UserMailer.subscribe_message(user, locale).deliver_now if user.customer.test
        end
      rescue Net::SMTPFatalError => e
        if e.message.include?('User unknown in virtual mailbox table')
          puts e.inspect
        else
          raise
        end
      end
    end
  end
end
