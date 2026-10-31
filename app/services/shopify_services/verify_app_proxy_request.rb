module ShopifyServices
  class VerifyAppProxyRequest
    MAX_TIMESTAMP_SKEW = 5.minutes
    SIGNATURE_PATTERN = /\A[0-9a-f]{64}\z/

    class Error < StandardError; end
    class ConfigurationError < Error; end
    class InvalidRequest < Error; end

    def self.call(request)
      new(request).call
    end

    def initialize(request)
      @request = request
    end

    def call
      secret = ENV["SHOPIFY_API_SECRET"].presence
      expected_shop = ENV["SHOPIFY_STORE_DOMAIN"].to_s.downcase
      expected_prefix = ENV.fetch("SHOPIFY_APP_PROXY_PATH_PREFIX", "/apps/ofp-quotes")

      if secret.blank? || expected_shop.blank?
        raise ConfigurationError, "Shopify app proxy credentials are not configured"
      end

      parameters = Rack::Utils.parse_query(@request.query_string)
      signature = parameters.delete("signature")
      raise InvalidRequest unless signature.is_a?(String) && signature.match?(SIGNATURE_PATTERN)
      raise InvalidRequest unless parameters["shop"] == expected_shop
      raise InvalidRequest unless parameters["path_prefix"] == expected_prefix
      raise InvalidRequest unless fresh_timestamp?(parameters["timestamp"])
      raise InvalidRequest unless valid_signature?(parameters, signature, secret)

      expected_prefix
    end

    private

    def fresh_timestamp?(timestamp)
      return false unless timestamp.to_s.match?(/\A\d{10,}\z/)

      (Time.current.to_i - timestamp.to_i).abs <= MAX_TIMESTAMP_SKEW.to_i
    end

    def valid_signature?(parameters, signature, secret)
      message = parameters.map { |key, value| "#{key}=#{Array(value).join(',')}" }.sort.join
      calculated = OpenSSL::HMAC.hexdigest("SHA256", secret, message)
      ActiveSupport::SecurityUtils.secure_compare(signature, calculated)
    end
  end
end
