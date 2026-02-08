class CreateWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_deliveries do |t|
      t.references :report, null: false, foreign_key: true
      t.string :url
      t.jsonb :payload
      t.string :status
      t.integer :attempts

      t.timestamps
    end
    add_check_constraint :status,
      "status IN ('pending', 'delivered', 'failed')",
      name: "checks_status_valid"
  end
end
