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

ActiveRecord::Schema[8.1].define(version: 2026_10_02_090000) do
  create_table "quote_requests", force: :cascade do |t|
    t.string "artwork_status", null: false
    t.boolean "contact_consent", default: false, null: false
    t.string "contact_name", null: false
    t.datetime "created_at", null: false
    t.string "delivery_method", default: "pickup", null: false
    t.text "description", null: false
    t.string "email", null: false
    t.date "event_date"
    t.boolean "information_confirmed", default: false, null: false
    t.date "needed_by"
    t.string "organization_name"
    t.string "other_project_type"
    t.string "phone"
    t.string "position_title"
    t.string "preferred_contact_method", null: false
    t.json "project_details", default: {}, null: false
    t.json "project_types", default: [], null: false
    t.string "public_reference", null: false
    t.string "quantity_summary", null: false
    t.boolean "rush_request", default: false, null: false
    t.string "shopify_draft_order_id"
    t.string "status", default: "new", null: false
    t.datetime "updated_at", null: false
    t.index ["public_reference"], name: "index_quote_requests_on_public_reference", unique: true
    t.index ["shopify_draft_order_id"], name: "index_quote_requests_on_shopify_draft_order_id", unique: true
  end
end
