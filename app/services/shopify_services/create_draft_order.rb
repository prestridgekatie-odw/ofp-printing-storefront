require "net/http"

module ShopifyServices
  class CreateDraftOrder
    Result = Struct.new(:draft_order_id, keyword_init: true)

    class Error < StandardError; end

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
      domain, token = shopify_credentials
      uri = URI("https://#{domain}/admin/api/#{api_version}/graphql.json")
      response = Net::HTTP.post(
        uri,
        JSON.generate(query: MUTATION, variables: { input: draft_order_input }),
        "Content-Type" => "application/json",
        "X-Shopify-Access-Token" => token
      )

      raise Error, "Shopify returned HTTP #{response.code}" unless response.code.to_i.between?(200, 299)

      body = JSON.parse(response.body)
      raise Error, "Shopify GraphQL request failed" if body["errors"].present?

      payload = body.dig("data", "draftOrderCreate")
      user_errors = Array(payload&.fetch("userErrors", []))
      raise Error, "Shopify rejected the draft order: #{user_errors.map { |error| error['message'] }.join('; ')}" if user_errors.any?

      draft_order_id = payload&.dig("draftOrder", "id")
      raise Error, "Shopify returned no draft order ID" if draft_order_id.blank?

      Result.new(draft_order_id: draft_order_id)
    rescue JSON::ParserError, SocketError, Timeout::Error, IOError, SystemCallError, OpenSSL::SSL::SSLError => error
      raise Error, "Shopify request failed (#{error.class})"
    end

    private

    def shopify_credentials
      domain = ENV["SHOPIFY_STORE_DOMAIN"].to_s.downcase
      token = ENV["SHOPIFY_ADMIN_ACCESS_TOKEN"].to_s
      raise Error, "SHOPIFY_STORE_DOMAIN must be a permanent .myshopify.com domain" unless domain.match?(/\A[a-z0-9][a-z0-9-]*\.myshopify\.com\z/)
      raise Error, "SHOPIFY_ADMIN_ACCESS_TOKEN is not configured" if token.blank?

      [domain, token]
    end

    def api_version
      version = ENV.fetch("SHOPIFY_ADMIN_API_VERSION", "2026-07")
      raise Error, "SHOPIFY_ADMIN_API_VERSION is invalid" unless version.match?(/\A\d{4}-\d{2}\z/)

      version
    end

    def draft_order_input
      {
        email: @intake.email,
        note: draft_order_note,
        tags: %w[quote-request pending-proof],
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
  end
end