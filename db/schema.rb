# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_08_021008) do
  create_table "candidates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "dob"
    t.string "email", null: false
    t.string "name", null: false
    t.string "ssn", null: false
    t.datetime "updated_at", null: false
  end

  create_table "checks", force: :cascade do |t|
    t.string "check_type", null: false
    t.datetime "created_at", null: false
    t.json "provider_response"
    t.bigint "report_id", null: false
    t.json "result"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["report_id", "status"], name: "index_checks_on_report_id_and_status"
    t.index ["report_id"], name: "index_checks_on_report_id"
    t.check_constraint "check_type IN ('criminal', 'employment', 'education')", name: "checks_check_type_valid"
    t.check_constraint "status IN ('pending', 'processing', 'completed', 'failed')", name: "checks_status_valid_chk"
  end

  create_table "reports", force: :cascade do |t|
    t.bigint "candidate_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "idempotency_key", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_id"], name: "index_reports_on_candidate_id"
    t.index ["idempotency_key"], name: "index_reports_on_idempotency_key", unique: true
    t.check_constraint "status IN ('pending', 'processing', 'completed', 'failed')", name: "reports_status_valid_chk"
  end

  create_table "webhook_deliveries", force: :cascade do |t|
    t.integer "attempts"
    t.datetime "created_at", null: false
    t.json "payload"
    t.bigint "report_id", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["report_id"], name: "index_webhook_deliveries_on_report_id"
    t.check_constraint "status IN ('pending', 'delivered', 'failed')", name: "webhook_deliveries_status_valid_chk"
  end

  add_foreign_key "checks", "reports"
  add_foreign_key "reports", "candidates"
  add_foreign_key "webhook_deliveries", "reports"
end
