class AddMessaging < ActiveRecord::Migration[6.1]
  def up
    add_column :resellers, :messagings, :jsonb, default: {}, null: false

    create_table :messaging_logs do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :service, null: false
      t.string :recipient
      t.text :content
      t.string :message_id, index: true
      t.jsonb :details, default: {}, null: false
      t.timestamps
    end

    Reseller.all.each { |reseller|
      reseller.messagings = {
        vonage: {
          api_key: reseller.sms_api_key,
          api_secret: reseller.sms_api_secret
        }
      }
      reseller.save!
    }

    remove_column :resellers, :sms_api_key
    remove_column :resellers, :sms_api_secret
  end

  def down
    add_column :resellers, :sms_api_key
    add_column :resellers, :sms_api_secret

    Reseller.all.each { |reseller|
      reseller.sms_api_key = reseller.messagings['vonage']['api_key']
      reseller.sms_api_secret = reseller.messagings['vonage']['api_secret']
      reseller.save!
    }

    drop_table :messaging_logs
    remove_column :resellers, :messagings
  end
end
