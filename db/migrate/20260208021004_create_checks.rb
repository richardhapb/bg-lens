class CreateChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :checks do |t|
      t.references :report, null: false, foreign_key: true
      t.string :check_type
      t.string :status
      t.jsonb :result
      t.jsonb :provider_response

      t.timestamps
    end
  end
end
