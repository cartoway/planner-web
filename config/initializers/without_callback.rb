require 'set'

module ActiveSupport::Callbacks::ClassMethods
  def without_callback(*args, &block)
    # Get all Filters (meaning all callback names as symboles)
    filters = get_callbacks(args.first)
                        .select { |c| c.kind == args.second }
                        .map(&:filter)

    unless filters.include?(args.last)
      raise Exception.new("Attempt to suppress a non existing callback") if Rails.env.development? || Rails.env.test?
    end

    mutex = Mutex.new
    mutex.synchronize do
      begin
        skip_callback(*args)
        yield
      ensure
        set_callback(*args)
      end
    end
  end
end
