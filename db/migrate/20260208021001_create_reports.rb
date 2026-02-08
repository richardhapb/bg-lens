class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.references :candidate, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :idempotency_key, null: false, unique: true
      t.datetime :completed_at

      t.timestamps
    end
    add_check_constraint :checks,
      "status IN ('pending', 'processing', 'completed', 'failed')",
      name: "checks_status_valid"

    add_index :reports, :idempotency_key, unique: true
  end
end
