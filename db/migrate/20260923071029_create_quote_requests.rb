class CreateQuoteRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :quote_requests do |t|
      t.string :organization_name
      t.string :contact_name, null: false
      t.string :position_title
      t.string :phone
      t.string :email, null: false
      t.string :preferred_contact_method, null: false
      t.json :project_types, null: false, default: []
      t.string :other_project_type
      t.string :quantity_summary, null: false
      t.date :needed_by
      t.date :event_date
      t.boolean :rush_request, null: false, default: false
      t.string :delivery_method, null: false, default: "pickup"
      t.text :description, null: false
      t.string :artwork_status, null: false
      t.boolean :information_confirmed, null: false, default: false
      t.boolean :contact_consent, null: false, default: false
      t.string :status, null: false, default: "new"
      t.string :public_reference, null: false

      t.timestamps
    end

    add_index :quote_requests, :public_reference, unique: true
  end
end
