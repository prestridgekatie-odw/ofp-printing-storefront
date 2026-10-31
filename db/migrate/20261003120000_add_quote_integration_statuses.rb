class AddQuoteIntegrationStatuses < ActiveRecord::Migration[8.1]
  def change
    add_column :quote_requests, :notification_status, :string, default: "pending", null: false
    add_column :quote_requests, :notification_error, :string
    add_column :quote_requests, :shopify_draft_order_status, :string, default: "pending", null: false
    add_column :quote_requests, :shopify_draft_order_error, :string
  end
end
