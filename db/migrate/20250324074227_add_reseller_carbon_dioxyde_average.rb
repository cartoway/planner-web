class AddResellerCarbonDioxydeAverage < ActiveRecord::Migration[6.1]
  def change
    add_column :resellers, :carbon_dioxyde_average, :float, default: 0.194 # 194.0 gCO2/delivery in Europe
    # source: https://clean-mobility.org/wp-content/uploads/2022/07/Secret-Emissions-of-E-Commerce.pdf
  end
end
