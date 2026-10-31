require "test_helper"

class ShopifyDraftOrderJobTest < ActiveJob::TestCase
  setup do
    @quote_request = QuoteRequest.create!(
      contact_name: "Jordan Smith",
      email: "jordan@example.com",
      phone: "555-0100",
      preferred_contact_method: "email",
      project_types: ["Sports Uniforms"],
      project_details: { "sports_uniforms" => { "sport" => "football", "garment_types" => ["jersey"], "decoration_methods" => ["sublimation"] } },
      quantity_summary: "24 uniforms",
      description: "Uniforms for a community team.",
      artwork_status: "existing_artwork",
      delivery_method: "pickup",
      information_confirmed: true,
      contact_consent: true,
      shopify_draft_order_status: "queued"
    )
  end

  test "creates an order once and records the shared reference" do
    calls = 0
    with_draft_order_service(->(_intake) do
      calls += 1
      _intake.update!(shopify_draft_order_id: "gid://shopify/DraftOrder/123")
      ShopifyServices::CreateDraftOrder::Result.new(draft_order_id: "gid://shopify/DraftOrder/123")
    end) do
      2.times { ShopifyDraftOrderJob.perform_now(@quote_request.public_reference) }
    end

    assert_equal 1, calls
    assert_equal "created", @quote_request.reload.shopify_draft_order_status
    assert_equal "gid://shopify/DraftOrder/123", @quote_request.shopify_draft_order_id
  end

  test "records and re-raises draft-order failures" do
    with_draft_order_service(->(_intake) { raise ShopifyServices::CreateDraftOrder::Error, "Shopify unavailable" }) do
      assert_raises(ShopifyServices::CreateDraftOrder::Error) do
        ShopifyDraftOrderJob.perform_now(@quote_request.public_reference)
      end
    end

    assert_equal "failed", @quote_request.reload.shopify_draft_order_status
    assert_equal "ShopifyServices::CreateDraftOrder::Error", @quote_request.shopify_draft_order_error
  end

  private

  def with_draft_order_service(replacement)
    service = ShopifyServices::CreateDraftOrder
    original_call = service.method(:call)
    service.define_singleton_method(:call) { |intake:| replacement.call(intake) }
    yield
  ensure
    service.define_singleton_method(:call, original_call)
  end
end
