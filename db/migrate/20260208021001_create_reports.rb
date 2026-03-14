class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.references :candidate, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :idempotency_key, null: false
      t.datetime :completed_at

      t.timestamps
    end
    add_check_constraint :reports,
      "status IN ('pending', 'processing', 'completed', 'failed')",
      name: "reports_status_valid_chk"

    add_index :reports, :idempotency_key, unique: true
  end
end
