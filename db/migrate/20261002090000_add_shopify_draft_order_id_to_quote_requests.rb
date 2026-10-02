class AddShopifyDraftOrderIdToQuoteRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :quote_requests, :shopify_draft_order_id, :string
    add_index :quote_requests, :shopify_draft_order_id, unique: true
  end
end