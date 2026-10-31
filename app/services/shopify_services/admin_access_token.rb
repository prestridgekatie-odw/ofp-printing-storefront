require "net/http"

module ShopifyServices
  class AdminAccessToken
    class Error < StandardError; end

    REQUIRED_SCOPES = %w[read_draft_orders write_draft_orders].freeze

    def self.call
      new.call
    end

    def call
      domain = ENV.fetch("SHOPIFY_STORE_DOMAIN").downcase
      client_id = ENV.fetch("SHOPIFY_API_KEY")
      client_secret = ENV.fetch("SHOPIFY_API_SECRET")
      unless domain.match?(/\A[a-z0-9][a-z0-9-]*\.myshopify\.com\z/) && client_id.present? && client_secret.present?
        raise Error, "Shopify Admin API credentials are invalid or incomplete"
      end

      Rails.cache.fetch("shopify-admin-token:#{domain}:#{client_id}", expires_in: 23.hours) do
        fetch_token(domain, client_id, client_secret)
      end
    rescue KeyError => error
      raise Error, "Shopify Admin API credentials are not configured (#{error.key})"
    end

    private

    def fetch_token(domain, client_id, client_secret)
      uri = URI("https://#{domain}/admin/oauth/access_token")
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(
        client_id: client_id,
        client_secret: client_secret,
        grant_type: "client_credentials"
      )
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
        http.request(request)
      end
      raise Error, "Shopify token endpoint returned HTTP #{response.code}" unless response.code.to_i.between?(200, 299)

      body = JSON.parse(response.body)
      access_token = body["access_token"].to_s
      scopes = body["scope"].to_s.split(",").map(&:strip)
      raise Error, "Shopify token response did not include an access token" if access_token.blank?
      raise Error, "Shopify app is missing required Draft Order access scopes" unless (REQUIRED_SCOPES - scopes).empty?

      access_token
    rescue JSON::ParserError, SocketError, Timeout::Error, IOError, SystemCallError, OpenSSL::SSL::SSLError => error
      raise Error, "Shopify token request failed (#{error.class})"
    end
  end
end
