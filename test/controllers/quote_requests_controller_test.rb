require "test_helper"

class QuoteRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    @payload = {
      contact_name: "Jordan Smith",
      email: "jordan@example.com",
      phone: "555-0100",
      preferred_contact_method: "email",
      project_types: ["Sports Uniforms"],
      project_details: { "sports_uniforms" => { "sport" => "football", "garment_types" => ["jersey"], "decoration_methods" => ["sublimation"] } },
      quantity_summary: "24 uniforms",
      description: "Uniforms for a community team.",
      artwork_status: "existing_artwork",
      delivery_method: "shipping",
      information_confirmed: "1",
      contact_consent: "1"
    }
  end

  test "renders the quote form with the honeypot" do
    get quote_path

    assert_response :success
    assert_select "form[action='#{quote_requests_path}']"
    assert_select "input[name='website']"
  end

  test "saves a request and queues both integrations with delivery method and consent" do
    assert_enqueued_jobs 2 do
      assert_difference("QuoteRequest.count", 1) do
        post quote_requests_path, params: { quote_request: @payload }
      end
    end

    request = QuoteRequest.order(:created_at).last
    assert_response :redirect
    assert_redirected_to confirmation_quote_request_path(request.public_reference)
    assert_equal "submitted_review", request.status
    assert_equal "shipping", request.delivery_method
    assert request.information_confirmed?
    assert request.contact_consent?
    assert_equal "queued", request.notification_status
    assert_equal "queued", request.shopify_draft_order_status
  end

  test "surfaces notification enqueue failures on the reference-only confirmation page" do
    with_job_enqueue_failure(QuoteRequestNotificationJob) do
      assert_difference("QuoteRequest.count", 1) do
        post quote_requests_path, params: { quote_request: @payload }
      end
    end

    request = QuoteRequest.order(:created_at).last
    assert_response :redirect
    assert_equal "failed", request.notification_status
    assert_equal "queued", request.shopify_draft_order_status

    get confirmation_quote_request_path(request.public_reference)

    assert_response :success
    assert_select "[role='alert']", text: /internal follow-up could not be completed/
    assert_not_includes response.body, request.email
  end

  test "does not persist a submission when the honeypot is filled" do
    assert_no_difference("QuoteRequest.count") do
      post quote_requests_path, params: { website: "spam", quote_request: @payload }
    end

    assert_response :unprocessable_entity
  end

  test "does not persist invalid submissions" do
    assert_no_difference("QuoteRequest.count") do
      post quote_requests_path, params: { quote_request: @payload.merge(email: "invalid", project_types: []) }
    end

    assert_response :unprocessable_entity
  end

  test "does not persist submissions without consent" do
    assert_no_difference("QuoteRequest.count") do
      post quote_requests_path, params: { quote_request: @payload.merge(contact_consent: "0") }
    end

    assert_response :unprocessable_entity
  end

  test "enforces conditional project detail requirements on submission" do
    invalid_details = { "sports_uniforms" => { "sport" => "football", "garment_types" => ["jersey"], "decoration_methods" => ["sublimation"] } }

    assert_no_difference("QuoteRequest.count") do
      post quote_requests_path, params: { quote_request: @payload.merge(
        project_details: invalid_details.merge("sports_uniforms" => invalid_details["sports_uniforms"].merge("sport" => "other"))
      ) }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Other sport is required when Other is selected"
  end

  test "reopens selected project details when validation fails" do
    post quote_requests_path, params: { quote_request: @payload.merge(quantity_summary: "") }

    assert_response :unprocessable_entity
    assert_select "#project-details-sports-uniforms:not([hidden])"
    assert_select "#project-type-sports-uniforms[aria-expanded='true']"
    assert_select "#project-detail-sports_uniforms-sport-football:not([disabled])"
  end

  test "limits quote submissions to five per minute" do
    5.times { post quote_requests_path, params: { quote_request: @payload } }
    post quote_requests_path, params: { quote_request: @payload }

    assert_response :redirect
    assert_redirected_to quote_path
    assert_equal "Too many attempts. Please wait a minute.", flash[:alert]
  end

  test "confirmation does not expose private submission data" do
    request = QuoteRequest.create!(@payload)

    get confirmation_quote_request_path(request.public_reference)

    assert_response :success
    assert_includes response.body, request.public_reference
    assert_not_includes response.body, request.email
    assert_not_includes response.body, request.description
  end

  test "rejects unsigned app-proxy requests" do
    with_proxy_credentials do
      get shopify_quote_path

      assert_response :forbidden
    end
  end

  test "renders the proxy form with its storefront action and one-use token" do
    with_proxy_credentials do
      get proxy_url(shopify_quote_path, signed_proxy_parameters)

      assert_response :success
      assert_select "form[action='/apps/ofp-quotes']"
      assert_select "input[name='proxy_form_token'][value]"
      assert_select "input[name='authenticity_token']", count: 0
    end
  end

  test "accepts a signed proxy submission and redirects through the storefront prefix" do
    with_proxy_credentials do
      get proxy_url(shopify_quote_path, signed_proxy_parameters)
      token = Nokogiri::HTML(response.body).at_css("input[name='proxy_form_token']")["value"]

      assert_enqueued_jobs 2 do
        assert_difference("QuoteRequest.count", 1) do
          post proxy_url(shopify_quote_requests_path, signed_proxy_parameters),
            params: { proxy_form_token: token, quote_request: @payload }
        end
      end

      request = QuoteRequest.order(:created_at).last
      assert_response :redirect
      assert_redirected_to "/apps/ofp-quotes/confirmation/#{request.public_reference}"
      assert_equal "shipping", request.delivery_method
    end
  end

  test "rejects a replayed proxy form token" do
    with_proxy_credentials do
      get proxy_url(shopify_quote_path, signed_proxy_parameters)
      token = Nokogiri::HTML(response.body).at_css("input[name='proxy_form_token']")["value"]
      post proxy_url(shopify_quote_requests_path, signed_proxy_parameters),
        params: { proxy_form_token: token, quote_request: @payload }

      assert_no_difference("QuoteRequest.count") do
        post proxy_url(shopify_quote_requests_path, signed_proxy_parameters),
          params: { proxy_form_token: token, quote_request: @payload }
      end

      assert_response :unprocessable_entity
      assert_includes response.body, "This form expired"
    end
  end

  test "rejects invalid signatures, other shops, and stale proxy requests" do
    with_proxy_credentials do
      invalid_signature = signed_proxy_parameters.merge("signature" => "f" * 64)
      get proxy_url(shopify_quote_path, invalid_signature)
      assert_response :forbidden

      wrong_shop = signed_proxy_parameters("shop" => "other.myshopify.com")
      get proxy_url(shopify_quote_path, wrong_shop)
      assert_response :forbidden

      stale_request = signed_proxy_parameters("timestamp" => (10.minutes.ago.to_i).to_s)
      get proxy_url(shopify_quote_path, stale_request)
      assert_response :forbidden
    end
  end

  private

  def with_proxy_credentials
    previous = %w[SHOPIFY_API_SECRET SHOPIFY_STORE_DOMAIN SHOPIFY_APP_PROXY_PATH_PREFIX].to_h do |key|
      [key, ENV[key]]
    end
    ENV["SHOPIFY_API_SECRET"] = "proxy-secret-for-tests"
    ENV["SHOPIFY_STORE_DOMAIN"] = "ofp-test.myshopify.com"
    ENV["SHOPIFY_APP_PROXY_PATH_PREFIX"] = "/apps/ofp-quotes"
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  def signed_proxy_parameters(overrides = {})
    parameters = {
      "shop" => "ofp-test.myshopify.com",
      "logged_in_customer_id" => "",
      "path_prefix" => "/apps/ofp-quotes",
      "timestamp" => Time.current.to_i.to_s
    }.merge(overrides)
    canonical = parameters.map { |key, value| "#{key}=#{Array(value).join(',')}" }.sort.join
    parameters.merge("signature" => OpenSSL::HMAC.hexdigest("SHA256", "proxy-secret-for-tests", canonical))
  end

  def proxy_url(path, parameters)
    "#{path}?#{Rack::Utils.build_query(parameters)}"
  end

  def with_job_enqueue_failure(job_class)
    original_perform_later = job_class.method(:perform_later)
    job_class.define_singleton_method(:perform_later) do |*|
      raise ActiveJob::EnqueueError, "queue unavailable"
    end
    yield
  ensure
    job_class.define_singleton_method(:perform_later, original_perform_later)
  end
end
