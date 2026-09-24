class AddProjectDetailsToQuoteRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :quote_requests, :project_details, :json, null: false, default: {}
  end
end