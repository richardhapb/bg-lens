class CreateChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :checks do |t|
      t.references :report, null: false, foreign_key: true
      t.string :check_type, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :result
      t.jsonb :provider_response

      t.timestamps
    end

    add_check_constraint :check_type,
      "check_type IN ('criminal', 'employment', 'education')",
      name: "checks_check_type_valid"

    add_check_constraint :checks,
      "status IN ('pending', 'processing', 'completed', 'failed')",
      name: "checks_status_valid"

    add_index :checks, [ :report_id, :status ]
  end
end
