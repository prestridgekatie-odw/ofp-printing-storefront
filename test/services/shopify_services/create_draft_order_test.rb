require "test_helper"

class ShopifyServices::CreateDraftOrderTest < ActiveSupport::TestCase
  test "creates an unpriced draft order with the quote details and review tags" do
    with_shopify_credentials do
      intake = QuoteRequest.new(
        public_reference: "OFP-ABC123DEF456G789",
        contact_name: "Jordan Smith",
        email: "jordan@example.com",
        phone: "555-0100",
        preferred_contact_method: "email",
        project_types: ["Sports Uniforms"],
        quantity_summary: "24 uniforms",
        description: "Uniforms for a community team.",
        artwork_status: "existing_artwork",
        delivery_method: "pickup"
      )
      response = Struct.new(:code, :body).new("200", JSON.generate(
        data: { draftOrderCreate: { draftOrder: { id: "gid://shopify/DraftOrder/123" }, userErrors: [] } }
      ))
      request_body = nil
      request_headers = nil

      with_http_post(->(_uri, body, headers) { request_body = JSON.parse(body); request_headers = headers; response }) do
        result = ShopifyServices::CreateDraftOrder.call(intake: intake)

        assert_equal "gid://shopify/DraftOrder/123", result.draft_order_id
      end

      input = request_body.dig("variables", "input")
      assert_equal "jordan@example.com", input["email"]
      assert_equal %w[quote-request pending-proof], input["tags"]
      assert_equal [{ "key" => "Quote request", "value" => "OFP-ABC123DEF456G789" }], input["customAttributes"]
      assert_includes input["note"], "This is an unpriced quote intake"
      assert_equal "token-for-test", request_headers["X-Shopify-Access-Token"]
      assert_equal [{
        "title" => "Unpriced quote request OFP-ABC123DEF456G789",
        "quantity" => 1,
        "originalUnitPrice" => "0.00",
        "taxable" => false
      }], input["lineItems"]
    end
  end

  test "raises a service error for Shopify GraphQL user errors" do
    with_shopify_credentials do
      response = Struct.new(:code, :body).new("200", JSON.generate(
        data: { draftOrderCreate: { draftOrder: nil, userErrors: [{ message: "Invalid email" }] } }
      ))

      with_http_post(->(*) { response }) do
        error = assert_raises(ShopifyServices::CreateDraftOrder::Error) do
          ShopifyServices::CreateDraftOrder.call(intake: QuoteRequest.new)
        end
        assert_includes error.message, "Invalid email"
      end
    end
  end

  private

  def with_shopify_credentials
    previous = %w[SHOPIFY_STORE_DOMAIN SHOPIFY_ADMIN_ACCESS_TOKEN SHOPIFY_ADMIN_API_VERSION].to_h do |key|
      [key, ENV[key]]
    end
    ENV["SHOPIFY_STORE_DOMAIN"] = "example.myshopify.com"
    ENV["SHOPIFY_ADMIN_ACCESS_TOKEN"] = "token-for-test"
    ENV["SHOPIFY_ADMIN_API_VERSION"] = "2026-07"
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  def with_http_post(replacement)
    original = Net::HTTP.method(:post)
    Net::HTTP.singleton_class.define_method(:post, replacement)
    yield
  ensure
    Net::HTTP.singleton_class.define_method(:post, original)
  end
end