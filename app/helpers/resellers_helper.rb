module ResellersHelper
  include CustomersHelper

  def reseller_default_profile_router_grouped_options(reseller)
    profile_router_grouped_options_for_admin(nil, reseller: reseller)
  end

  def reseller_default_profile_router_selected_value(reseller)
    reseller_default_profile_router_combined_value(reseller)
  end

  def messaging_services(reseller)
    messaging_service_objects(reseller).map{ |values|
      {
        name: values[:name],
        definition: values[:class].definition,
        balance: balance_hash(values[:service])
      }
    }
  end

  private

  def balance_hash(service)
    balance = service.balance

    if balance.is_a?(String)
      return {
        value: balance,
        color_class: 'danger'
      }
    end

    color_class =
      case balance&.round
      when 0
        'danger'
      when 1..20
        'warning'
      when nil
        'secondary'
      else
        'success'
      end
    {
      value: balance&.round(2),
      color_class: color_class
    }
  end

  def messaging_service_objects(reseller)
    MESSAGING_SERVICES.map do |key, service_class|
      {
        name: key,
        service: service_class.new(reseller),
        class: service_class
      }
    end
  end
end
