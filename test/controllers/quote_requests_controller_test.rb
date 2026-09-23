require "test_helper"

class QuoteRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    QuoteRequestsController::RATE_LIMIT_STORE.clear
    @payload = {
      contact_name: "Jordan Smith",
      email: "jordan@example.com",
      phone: "555-0100",
      preferred_contact_method: "email",
      project_types: ["Sports Uniforms"],
      quantity_summary: "24 uniforms",
      description: "Uniforms for a community team.",
      artwork_status: "existing_artwork",
      delivery_method: "pickup",
      information_confirmed: "1",
      contact_consent: "1"
    }
  end

  test "renders the quote form" do
    get quote_path

    assert_response :success
    assert_select "form[action='#{quote_requests_path}']"
    assert_select "input[name='website']"
    assert_select "[data-controller='quote-form']"
    assert_select "[data-step='1']"
    assert_select "[data-step='2']"
    assert_select "[data-step='3']"
    assert_select "button[type='button']", minimum: 3
    assert_select "input[type='submit'][value='Submit quote request']", count: 1
  end

  test "persists a valid request and redirects to a private confirmation" do
    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      post quote_requests_path, params: { quote_request: @payload }
    end

    request = QuoteRequest.order(:created_at).last
    assert_response :redirect
    assert_redirected_to confirmation_quote_request_path(request.public_reference)
    assert_match(/\AOFP-[A-Z0-9]{16}\z/, request.public_reference)
  end

  test "does not persist invalid submissions" do
    assert_no_difference("QuoteRequest.count") do
      post quote_requests_path, params: { quote_request: @payload.merge(email: "not-an-email", project_types: []) }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors"
  end

  test "rejects a filled honeypot" do
    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      assert_no_difference("QuoteRequest.count") do
        post quote_requests_path, params: { website: "spam", quote_request: @payload }
      end
    end

    assert_response :unprocessable_entity
  end

  test "does not rate limit quote form pages" do
    6.times do
      get quote_path
      assert_response :success
    end
  end

  test "limits submissions to five per hour per IP" do
    5.times { post quote_requests_path, params: { quote_request: @payload } }

    post quote_requests_path, params: { quote_request: @payload }

    assert_response :too_many_requests
  end

  test "confirmation does not expose private submission data" do
    request = QuoteRequest.create!(@payload)

    get confirmation_quote_request_path(request.public_reference)

    assert_response :success
    assert_includes response.body, request.public_reference
    assert_includes response.body, "OFP will review your request and contact you with next steps."
    assert_not_includes response.body, request.email
    assert_not_includes response.body, request.contact_name
    assert_not_includes response.body, request.description
    assert_not_includes response.body, "quote_request_id"
    assert_select "a[href='#{root_path}']", minimum: 2
    assert_select "a[href='#{quote_path}']", count: 1
  end

  test "returns a generic not found response for an unknown confirmation reference" do
    get confirmation_quote_request_path("OFP-UNKNOWNREFERENCE")

    assert_response :not_found
  end

  test "homepage quote CTAs point to the quote form" do
    get root_path

    assert_response :success
    assert_select "a[href='#{quote_path}']", count: 3
  end

  test "a notification enqueue failure does not prevent persistence" do
    original_notification = QuoteRequestMailer.method(:notification)
    QuoteRequestMailer.singleton_class.send(:define_method, :notification) do |*|
      raise ActiveJob::EnqueueError, "mail unavailable"
    end

    begin
      assert_difference("QuoteRequest.count", 1) do
        post quote_requests_path, params: { quote_request: @payload }
      end
    ensure
      QuoteRequestMailer.singleton_class.send(:define_method, :notification, original_notification)
    end

    assert_response :redirect
  end

  test "does not allow public status or reference assignment" do
    post quote_requests_path, params: {
      quote_request: @payload.merge(status: "closed", public_reference: "OFP-MALICIOUSREFERENCE")
    }

    request = QuoteRequest.order(:created_at).last
    assert_response :redirect
    assert_equal "new", request.status
    assert_match(/\AOFP-[A-Z0-9]{16}\z/, request.public_reference)
    assert_not_equal "OFP-MALICIOUSREFERENCE", request.public_reference
  end

  test "retries a public-reference collision up to three attempts" do
    attempts = 0
    original_save = QuoteRequest.instance_method(:save)
    QuoteRequest.define_method(:save) do |*args, **options|
      attempts += 1
      raise ActiveRecord::RecordNotUnique, "UNIQUE constraint failed: quote_requests.public_reference" if attempts < 3

      original_save.bind_call(self, *args, **options)
    end

    begin
      assert_difference("QuoteRequest.count", 1) do
        post quote_requests_path, params: { quote_request: @payload }
      end
    ensure
      QuoteRequest.define_method(:save, original_save)
    end

    assert_equal 3, attempts
    assert_response :redirect
  end

end
