class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.references :candidate, null: false, foreign_key: true
      t.string :status
      t.string :idempotency_key
      t.datetime :completed_at

      t.timestamps
    end
    add_index :reports, :idempotency_key, unique: true
  end
end
