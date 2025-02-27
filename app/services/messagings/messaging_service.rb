class CountryCodeError < StandardError; end

class MessagingService
  def self.definition
    raise NotImplementedError
  end

  def self.get_messaging_service_from_key(key)
    MESSAGING_SERVICES[key]
  end

  def initialize(customer, options = {})
    @customer = customer
    @reseller = customer.reseller
    @options = options
  end

  def send_message(to, content, options = {})
    raise NotImplementedError
  end

  def content(template, replacements: {}, truncate: true)
    # Display date only if key date is not present in template
    format_time = template.include?('{DATE}') ? :hour_minute : :short

    replacements.each{ |k, v|
      if v.is_a?(Time)
        # Shift time if {TIME+mn} or {TIME-mn} found in template
        regexp = Regexp.new("{#{k}([\-\+]?[0-9]*)}".upcase)
        template = template.gsub(regexp) { |s|
          shift_time = 0
          if (m = regexp.match(s)) && !m[1].blank?
            shift_time = Integer(m[1]).minutes
          end

          if shift_time != 0
            # Round time to quarter
            seconds = 15.minutes
            shift_time = (shift_time / shift_time.abs) * seconds if shift_time.abs < seconds
            shift_time = ((v + shift_time).to_f / seconds).round * seconds - v.to_i
          end

          I18n.l(v + shift_time, format: format_time)
        }
      elsif v.is_a?(Date)
        template = template.gsub("{#{k}}".upcase, I18n.l(v, format: :date))
      elsif k == :url && v.is_a?(String) && v.include?('{URL}')
        url_shortener = UrlShortenerService.new
        template = template.gsub("{#{k}}".upcase, url_shortener.shorten(v))
      else
        template = template.gsub("{#{k}}".upcase, "#{v}")
      end
    }

    truncate ? template[0..159] : template
  end

  def self.configured?(customer, service_name)
    return false unless customer.reseller.messagings&.key?(service_name)

    config = customer.reseller.messagings[service_name]
    ValueToBoolean.value_to_boolean(config['enable'])
  end

  def service_name
    self.class.name.split('::').last.underscore.gsub('_service', '')
  end

  protected

  def check_service_config
    config = @reseller.messagings&.dig(service_name)
    raise ArgumentError.new("#{self.class.name.split('::').last} not configured") unless config&.dig('enable')
    config
  end

  def format_phone_number(phone, country = nil)
    return phone if phone.start_with?('+', '00')

    if country
      begin
        country_code = IsoCountryCodes.search_by_name(country).first.alpha2
        raise CountryCodeError.new("Country code could not be identified: #{to} #{country_code}") unless country_code

        formatted_phone = Phonelib.parse(phone, country_code)
        return [] unless formatted_phone.type == :mobile

        "+#{formatted_phone.country_code}#{formatted_phone.raw_national}"
      rescue IsoCountryCodes::UnknownCodeError => e
        Rails.logger.error "Country code error: #{e.message}"
        raise CountryCodeError.new(e.message)
      end
    else
      raise CountryCodeError.new("Country is mandatory if the number is not in an international format")
    end
  end

  def create_message_log(to, content, response = {})
    @customer.messaging_logs.create!(
      service: service_name,
      recipient: to,
      content: content,
      details: response
    )
  end
end
