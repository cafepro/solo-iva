class CreateServiceTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :service_templates do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :billing_period, null: false, default: "custom"
      t.string :default_description
      t.decimal :default_base_imponible, precision: 10, scale: 2
      t.decimal :default_iva_rate, precision: 5, scale: 2, default: 21
    end

    add_index :service_templates, [ :user_id, :name ]
  end
end
