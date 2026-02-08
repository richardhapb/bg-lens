class CreateCandidates < ActiveRecord::Migration[8.1]
  def change
    create_table :candidates do |t|
      t.string :name
      t.string :ssn
      t.date :dob
      t.string :email

      t.timestamps
    end
  end
end
