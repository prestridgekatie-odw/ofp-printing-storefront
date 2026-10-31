require "test_helper"

class ShopifyServices::AdminAccessTokenTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    @previous = %w[SHOPIFY_STORE_DOMAIN SHOPIFY_API_KEY SHOPIFY_API_SECRET].to_h do |key|
      [key, ENV[key]]
    end
    ENV["SHOPIFY_STORE_DOMAIN"] = "example.myshopify.com"
    ENV["SHOPIFY_API_KEY"] = "client-id-for-test"
    ENV["SHOPIFY_API_SECRET"] = "client-secret-for-test"
  end

  teardown do
    Rails.cache.clear
    @previous.each { |key, value| ENV[key] = value }
  end

  test "exchanges server credentials and caches the scoped access token" do
    response = Struct.new(:code, :body).new("200", JSON.generate(
      access_token: "access-token-for-test",
      scope: "read_draft_orders,write_draft_orders",
      expires_in: 86_399
    ))
    request_body = nil
    original_start = Net::HTTP.method(:start)
    fake_http = Object.new
    fake_http.define_singleton_method(:request) do |request|
      request_body = URI.decode_www_form(request.body).to_h
      response
    end
    Net::HTTP.singleton_class.define_method(:start) { |*_, **_, &block| block.call(fake_http) }

    assert_equal "access-token-for-test", ShopifyServices::AdminAccessToken.call
    assert_equal "access-token-for-test", ShopifyServices::AdminAccessToken.call
    assert_equal "client_credentials", request_body["grant_type"]
    assert_equal "client-id-for-test", request_body["client_id"]
    assert_equal "client-secret-for-test", request_body["client_secret"]
  ensure
    Net::HTTP.singleton_class.define_method(:start, original_start)
  end

  test "rejects tokens missing required Draft Order scopes" do
    response = Struct.new(:code, :body).new("200", JSON.generate(
      access_token: "access-token-for-test",
      scope: "read_products",
      expires_in: 86_399
    ))
    original_start = Net::HTTP.method(:start)
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_request| response }
    Net::HTTP.singleton_class.define_method(:start) { |*_, **_, &block| block.call(fake_http) }

    assert_raises(ShopifyServices::AdminAccessToken::Error) do
      ShopifyServices::AdminAccessToken.call
    end
  ensure
    Net::HTTP.singleton_class.define_method(:start, original_start)
  end
end
