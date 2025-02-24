module ResellersHelper
  def messaging_services
    MESSAGING_SERVICES.map do |key, service_class|
      {
        name: key,
        definition: service_class.definition
      }
    end
  end
end
