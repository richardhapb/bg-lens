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
  end
end
