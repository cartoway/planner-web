class EnsureUniqueDriverTokensForVehicles < ActiveRecord::Migration[6.1]
  class MigrationVehicle < ActiveRecord::Base
    self.table_name = 'vehicles'
  end

  require 'securerandom'
  require Rails.root.join('scripts/cleanup_driver_shortlinks')

  def up
    rotated_tokens = ensure_tokens_present_and_unique
    CleanupDriverShortlinks.new(tokens: rotated_tokens).call
    add_index :vehicles, :driver_token, unique: true
  end

  def down
    remove_index :vehicles, :driver_token if index_exists?(:vehicles, :driver_token)
  end

  private

  def ensure_tokens_present_and_unique
    used_tokens = {}
    rotated_tokens = []

    MigrationVehicle.select(:id, :driver_token).find_each do |vehicle|
      token = vehicle.driver_token

      if token.blank? || used_tokens[token]
        rotated_tokens << token if token.present?
        token = generate_unique_token(used_tokens)
        vehicle.update_columns(driver_token: token)
      end

      used_tokens[token] = true
    end

    rotated_tokens
  end

  def generate_unique_token(used_tokens)
    loop do
      token = SecureRandom.urlsafe_base64(48)
      next if used_tokens[token]
      next if MigrationVehicle.where(driver_token: token).exists?

      return token
    end
  end
end
