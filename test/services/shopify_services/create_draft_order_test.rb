require "test_helper"

class ShopifyServices::CreateDraftOrderTest < ActiveSupport::TestCase
  setup do
    @intake = QuoteRequest.create!(
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
      contact_consent: true
    )
  end

  test "creates an unpriced draft order with quote details and a unique retry tag" do
    with_shopify_credentials do
      responses = [
        graphql_response(data: { draftOrders: { nodes: [] } }),
        graphql_response(data: { draftOrderCreate: { draftOrder: { id: "gid://shopify/DraftOrder/123" }, userErrors: [] } })
      ]

      with_http_responses(responses) do |bodies, headers, requests|
        result = ShopifyServices::CreateDraftOrder.call(intake: @intake)
        repeated_result = ShopifyServices::CreateDraftOrder.call(intake: @intake)

        assert_equal "gid://shopify/DraftOrder/123", result.draft_order_id
        assert_equal result.draft_order_id, repeated_result.draft_order_id
        assert_equal 2, requests.length

        input = bodies.last.dig("variables", "input")
        assert_equal "jordan@example.com", input["email"]
        assert_equal ["quote-request", "pending-proof", "ofp-quote-#{@intake.public_reference}"], input["tags"]
        assert_equal [{ "key" => "Quote request", "value" => @intake.public_reference }], input["customAttributes"]
        assert_includes input["note"], "This is an unpriced quote intake"
        assert_equal "token-for-test", headers.last["X-Shopify-Access-Token"]
        assert_equal [{
          "title" => "Unpriced quote request #{@intake.public_reference}",
          "quantity" => 1,
          "originalUnitPrice" => "0.00",
          "taxable" => false
        }], input["lineItems"]
        assert_equal "2026-10", requests.last.path.split("/")[3]
        assert_equal "gid://shopify/DraftOrder/123", @intake.reload.shopify_draft_order_id
      end
    end
  end

  test "reuses a matching Shopify order when a prior create response was interrupted" do
    with_shopify_credentials do
      responses = [
        graphql_response(data: { draftOrders: { nodes: [{ id: "gid://shopify/DraftOrder/existing" }] } })
      ]

      with_http_responses(responses) do |bodies, _headers, _requests|
        result = ShopifyServices::CreateDraftOrder.call(intake: @intake)

        assert_equal "gid://shopify/DraftOrder/existing", result.draft_order_id
        assert_equal 1, bodies.length
        assert_includes bodies.first.dig("variables", "query"), "tag:ofp-quote-#{@intake.public_reference}"
        assert_equal result.draft_order_id, @intake.reload.shopify_draft_order_id
      end
    end
  end

  test "raises a service error for Shopify GraphQL user errors" do
    with_shopify_credentials do
      responses = [
        graphql_response(data: { draftOrders: { nodes: [] } }),
        graphql_response(data: { draftOrderCreate: { draftOrder: nil, userErrors: [{ message: "Invalid email" }] } })
      ]

      with_http_responses(responses) do
        error = assert_raises(ShopifyServices::CreateDraftOrder::Error) do
          ShopifyServices::CreateDraftOrder.call(intake: @intake)
        end
        assert_includes error.message, "Invalid email"
        assert_nil @intake.reload.shopify_draft_order_id
      end
    end
  end

  test "does not create an order when Shopify omits search data" do
    with_shopify_credentials do
      with_http_responses([graphql_response]) do |bodies|
        assert_raises(ShopifyServices::CreateDraftOrder::Error) do
          ShopifyServices::CreateDraftOrder.call(intake: @intake)
        end

        assert_equal 1, bodies.length
        assert_nil @intake.reload.shopify_draft_order_id
      end
    end
  end

  private

  def with_shopify_credentials
    previous = %w[SHOPIFY_STORE_DOMAIN SHOPIFY_API_KEY SHOPIFY_API_SECRET SHOPIFY_ADMIN_API_VERSION].to_h do |key|
      [key, ENV[key]]
    end
    ENV["SHOPIFY_STORE_DOMAIN"] = "example.myshopify.com"
    ENV["SHOPIFY_API_KEY"] = "key-for-test"
    ENV["SHOPIFY_API_SECRET"] = "secret-for-test"
    ENV["SHOPIFY_ADMIN_API_VERSION"] = "2026-10"
    token_provider = ShopifyServices::AdminAccessToken
    original_call = token_provider.method(:call)
    token_provider.define_singleton_method(:call) { "token-for-test" }
    yield
  ensure
    token_provider.define_singleton_method(:call, original_call)
    previous.each { |key, value| ENV[key] = value }
  end

  def with_http_responses(responses)
    request_bodies = []
    request_headers = []
    requests = []
    fake_http = Object.new
    fake_http.define_singleton_method(:request) do |request|
      requests << request
      request_bodies << JSON.parse(request.body)
      request_headers << { "X-Shopify-Access-Token" => request["X-Shopify-Access-Token"] }
      responses.shift
    end
    original_start = Net::HTTP.method(:start)
    Net::HTTP.singleton_class.define_method(:start) { |*_, **_, &block| block.call(fake_http) }
    yield request_bodies, request_headers, requests
  ensure
    Net::HTTP.singleton_class.define_method(:start, original_start)
  end

  def graphql_response(data: nil, errors: nil)
    body = {}
    body[:data] = data if data
    body[:errors] = errors if errors
    Struct.new(:code, :body).new("200", JSON.generate(body))
  end
end
