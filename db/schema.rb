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

ActiveRecord::Schema[8.1].define(version: 2026_04_16_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "clients", force: :cascade do |t|
    t.string "address_line"
    t.string "city"
    t.string "country", default: "España", null: false
    t.string "name", null: false
    t.string "nif"
    t.string "postal_code"
    t.string "province"
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_clients_on_user_id_and_name"
    t.index ["user_id"], name: "index_clients_on_user_id"
  end

  create_table "invoice_lines", force: :cascade do |t|
    t.decimal "base_imponible", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.string "description"
    t.bigint "invoice_id", null: false
    t.decimal "iva_amount", precision: 10, scale: 2
    t.decimal "iva_rate", precision: 5, scale: 2
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_lines_on_invoice_id"
  end

  create_table "invoice_upload_stashes", force: :cascade do |t|
    t.binary "file_data", null: false
    t.string "filename", null: false
    t.string "token", null: false
    t.bigint "user_id", null: false
    t.index ["token"], name: "index_invoice_upload_stashes_on_token", unique: true
    t.index ["user_id"], name: "index_invoice_upload_stashes_on_user_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "client_id"
    t.datetime "created_at", null: false
    t.string "google_drive_file_id"
    t.datetime "google_drive_synced_at"
    t.date "invoice_date"
    t.string "invoice_number"
    t.integer "invoice_type"
    t.string "issuer_name"
    t.string "issuer_nif"
    t.text "notes"
    t.string "payment_signed_note"
    t.bigint "pdf_upload_id"
    t.string "recipient_address_line"
    t.string "recipient_city"
    t.string "recipient_country"
    t.string "recipient_name"
    t.string "recipient_nif"
    t.string "recipient_postal_code"
    t.string "recipient_province"
    t.date "service_period_end"
    t.date "service_period_start"
    t.binary "source_file_data"
    t.string "source_filename"
    t.string "status", default: "confirmed", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["client_id"], name: "index_invoices_on_client_id"
    t.index ["pdf_upload_id"], name: "index_invoices_on_pdf_upload_id"
    t.index ["status"], name: "index_invoices_on_status"
    t.index ["user_id", "invoice_type", "invoice_number"], name: "index_invoices_confirmed_user_type_number", unique: true, where: "((status)::text = 'confirmed'::text)"
    t.index ["user_id"], name: "index_invoices_on_user_id"
  end

  create_table "pdf_uploads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.binary "file_data", null: false
    t.string "filename", null: false
    t.integer "invoice_type", default: 1, null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_pdf_uploads_on_user_id"
  end

  create_table "service_templates", force: :cascade do |t|
    t.string "billing_period", default: "custom", null: false
    t.decimal "default_base_imponible", precision: 10, scale: 2
    t.string "default_description"
    t.decimal "default_iva_rate", precision: 5, scale: 2, default: "21.0"
    t.string "name", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_service_templates_on_user_id_and_name"
    t.index ["user_id"], name: "index_service_templates_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "billing_address_line"
    t.string "billing_city"
    t.string "billing_country"
    t.string "billing_display_name"
    t.string "billing_email"
    t.string "billing_nif"
    t.string "billing_phone"
    t.string "billing_postal_code"
    t.string "billing_province"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "google_drive_folder_name"
    t.string "google_drive_issued_folder_name"
    t.string "google_drive_received_folder_name"
    t.text "google_drive_refresh_token"
    t.boolean "google_drive_sync_enabled", default: false, null: false
    t.string "iban"
    t.integer "invoice_number_digit_count", default: 3, null: false
    t.integer "invoice_number_next", default: 1, null: false
    t.string "invoice_number_prefix", default: "F", null: false
    t.string "invoice_pdf_header_title"
    t.text "payment_methods_note"
    t.string "paypal_email"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "clients", "users"
  add_foreign_key "invoice_lines", "invoices"
  add_foreign_key "invoice_upload_stashes", "users"
  add_foreign_key "invoices", "clients"
  add_foreign_key "invoices", "pdf_uploads"
  add_foreign_key "invoices", "users"
  add_foreign_key "pdf_uploads", "users"
  add_foreign_key "service_templates", "users"
end
