class DeliverableUnitInitialLoad < Serializable
  def initialize(initial_loads)
    super(initial_loads)
    @hash = if initial_loads
      Hash[initial_loads.map{ |key, value|
        next unless value && !value.empty?

        # float value will be validated by the model
        new_value =
          begin
            Float(value)
          rescue StandardError
            value
          end
        [Integer(key), new_value]
      }.compact]
    else
      {}
    end
  end
end
