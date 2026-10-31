require "net/http"

module ShopifyServices
  class CreateDraftOrder
    Result = Struct.new(:draft_order_id, keyword_init: true)

    class Error < StandardError; end

    FIND_BY_QUOTE_TAG = <<~GRAPHQL.freeze
      query FindDraftOrderForQuote($query: String!) {
        draftOrders(first: 1, query: $query) {
          nodes {
            id
          }
        }
      }
    GRAPHQL

    MUTATION = <<~GRAPHQL.freeze
      mutation CreateDraftOrder($input: DraftOrderInput!) {
        draftOrderCreate(input: $input) {
          draftOrder {
            id
          }
          userErrors {
            field
            message
          }
        }
      }
    GRAPHQL

    def self.call(intake:)
      new(intake).call
    end

    def initialize(intake)
      @intake = intake
    end

    def call
      raise Error, "Quote request must be saved before creating a draft order" unless @intake.persisted?
      return Result.new(draft_order_id: @intake.shopify_draft_order_id) if @intake.shopify_draft_order_id.present?

      tag = quote_tag
      existing_id = find_existing_draft_order(tag)
      return persist_result(existing_id) if existing_id.present?

      payload = graphql_request(MUTATION, { input: draft_order_input(tag) })
      user_errors = Array(payload&.fetch("userErrors", []))
      if user_errors.any?
        raise Error, "Shopify rejected the draft order: #{user_errors.map { |error| error['message'] }.join('; ')}"
      end

      draft_order_id = payload&.dig("draftOrder", "id")
      raise Error, "Shopify returned no draft order ID" if draft_order_id.blank?

      persist_result(draft_order_id)
    end

    private

    def find_existing_draft_order(tag)
      result = graphql_request(FIND_BY_QUOTE_TAG, { query: "tag:#{tag}" })
      connection = result["draftOrders"]
      raise Error, "Shopify returned no draft-order search results" unless connection.is_a?(Hash)

      nodes = connection["nodes"]
      raise Error, "Shopify returned no draft-order search results" unless nodes.is_a?(Array)

      existing_order = nodes.first
      return if existing_order.nil?

      draft_order_id = existing_order["id"]
      raise Error, "Shopify returned a draft order without an ID" if draft_order_id.blank?

      draft_order_id
    end

    def graphql_request(document, variables)
      domain = ENV.fetch("SHOPIFY_STORE_DOMAIN").to_s.downcase
      raise Error, "SHOPIFY_STORE_DOMAIN must be a permanent .myshopify.com domain" unless domain.match?(/\A[a-z0-9][a-z0-9-]*\.myshopify\.com\z/)

      uri = URI("https://#{domain}/admin/api/#{api_version}/graphql.json")
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["X-Shopify-Access-Token"] = AdminAccessToken.call
      request.body = JSON.generate(query: document, variables: variables)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 20) do |http|
        http.request(request)
      end
      raise Error, "Shopify returned HTTP #{response.code}" unless response.code.to_i.between?(200, 299)

      body = JSON.parse(response.body)
      raise Error, "Shopify GraphQL request failed" if body["errors"].present?

      data = body["data"]
      raise Error, "Shopify returned no GraphQL data" unless data.is_a?(Hash)

      if document == MUTATION
        payload = data["draftOrderCreate"]
        raise Error, "Shopify returned no Draft Order result" unless payload.is_a?(Hash)

        payload
      else
        data
      end
    rescue KeyError => error
      raise Error, "Shopify configuration is incomplete (#{error.key})"
    rescue JSON::ParserError, SocketError, Timeout::Error, IOError, SystemCallError, OpenSSL::SSL::SSLError => error
      raise Error, "Shopify request failed (#{error.class})"
    end

    def api_version
      version = ENV.fetch("SHOPIFY_ADMIN_API_VERSION", "2026-10")
      raise Error, "SHOPIFY_ADMIN_API_VERSION is invalid" unless version.match?(/\A\d{4}-\d{2}\z/)

      version
    end

    def quote_tag
      "ofp-quote-#{@intake.public_reference}"
    end

    def draft_order_input(tag)
      {
        email: @intake.email,
        note: draft_order_note,
        tags: ["quote-request", "pending-proof", tag],
        lineItems: [{
          title: "Unpriced quote request #{@intake.public_reference}",
          quantity: 1,
          originalUnitPrice: "0.00",
          taxable: false
        }],
        customAttributes: [{ key: "Quote request", value: @intake.public_reference }]
      }
    end

    def draft_order_note
      [
        "Quote request #{@intake.public_reference}",
        "This is an unpriced quote intake. Replace the $0 placeholder with products and pricing after review before sending an invoice.",
        "Organization: #{@intake.organization_name}",
        "Contact: #{@intake.contact_name}",
        "Email: #{@intake.email}",
        "Phone: #{@intake.phone}",
        "Preferred contact: #{@intake.preferred_contact_method}",
        "Project types: #{@intake.project_types.join(', ')}",
        "Quantity: #{@intake.quantity_summary}",
        "Needed by: #{@intake.needed_by}",
        "Event date: #{@intake.event_date}",
        "Rush request: #{@intake.rush_request?}",
        "Delivery: #{@intake.delivery_method}",
        "Artwork status: #{@intake.artwork_status}",
        "Description: #{@intake.description}",
        "Project details: #{JSON.generate(@intake.project_details)}"
      ].join("\n")
    end

    def persist_result(draft_order_id)
      @intake.update!(shopify_draft_order_id: draft_order_id)
      Result.new(draft_order_id: draft_order_id)
    end
  end
end
