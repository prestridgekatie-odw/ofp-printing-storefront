  class CreateRosterLines < ActiveRecord::Migration[8.1]
  def change
    create_table :roster_lines do |t|
      t.references :quote_request, null: false, foreign_key: true
      t.string :player_name
      t.string :jersey_size
      t.string :pant_size
      t.string :short_size
      t.string :hoodie_size
      t.integer :number
      t.json :custom_properties

      t.timestamps
    end
  end
end