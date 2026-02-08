class CreateCandidates < ActiveRecord::Migration[8.1]
  def change
    create_table :candidates do |t|
      t.string :name, null: false
      t.string :ssn, null: false
      t.string :email, null: false
      t.date :dob

      t.timestamps
    end
  end
end
