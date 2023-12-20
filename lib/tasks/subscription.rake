namespace :subscription do
  desc 'Subscription manager'
  task :delete, [:number_of_days] => [:environment] do |_task, args|
    args.with_defaults(number_of_days: 30)
    if args.number_of_days.to_i.positive?
      date = Time.zone.today - args.number_of_days.to_i.days
      customers_to_del = Customer.where('end_subscription <= ?', date)
      puts "#{customers_to_del.count} subscription(s) expired since #{date} and will be deleted."
      customers_to_del.destroy_all
    else
      puts 'Invalid parameter: number should be an integer strictly positive.'
      abort # Return a nil value from the Rake proc
    end
  end
end
