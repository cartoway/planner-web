class CreateTableReseller < ActiveRecord::Migration
  def up
    create_table :resellers do |t|
      t.string :host, null: false
      t.string :name, null: false
      t.string :welcome_url
      t.string :help_url

      t.timestamps
    end

    reseller = Reseller.create(host: 'localhost:3000', name: 'Planner')

    add_column :customers, :reseller_id, :integer
    Customer.all.each{ |customer|
      customer.reseller = reseller
      customer.save!
    }
    change_column :customers, :reseller_id, :integer, null: false

    add_column :users, :reseller_id, :integer
    User.where(admin: true).each{ |user|
      user.reseller = reseller
      user.save!
    }
    remove_column :users, :admin
  end

  def down
    add_column :users, :admin, :boolean
    User.where.not(reseller_id: nil).each{ |user|
      user.admin = true
      user.save!
    }
    remove_column :users, :reseller_id

    remove_column :customers, :reseller_id

    drop_table :resellers
  end
end
