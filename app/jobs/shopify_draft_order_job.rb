class ShopifyDraftOrderJob < ApplicationJob
  queue_as :default

  def perform(public_reference)
    quote_request = QuoteRequest.find_by!(public_reference: public_reference)

    quote_request.with_lock do
      return if quote_request.shopify_draft_order_id.present?
      return if quote_request.shopify_draft_order_status == "created"

      quote_request.update!(shopify_draft_order_status: "processing", shopify_draft_order_error: nil)
      ShopifyServices::CreateDraftOrder.call(intake: quote_request)
      quote_request.update!(shopify_draft_order_status: "created", shopify_draft_order_error: nil)
    end
  rescue StandardError => error
    quote_request&.update!(shopify_draft_order_status: "failed", shopify_draft_order_error: error.class.name)
    Rails.logger.error("Shopify draft order failed for #{public_reference} (#{error.class})")
    raise
  end
end
