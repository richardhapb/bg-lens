class CreateWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_deliveries do |t|
      t.references :report, null: false, foreign_key: true
      t.string :url
      t.json :payload
      t.string :status
      t.integer :attempts

      t.timestamps
    end
    add_check_constraint :webhook_deliveries,
      "status IN ('pending', 'delivered', 'failed')",
      name: "webhook_deliveries_status_valid_chk"
  end
end
