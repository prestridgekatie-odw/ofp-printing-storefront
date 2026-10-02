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
			project_details: { "sports_uniforms" => { "sport" => "football", "garment_types" => ["jersey"], "decoration_methods" => ["sublimation"] } },
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
	end

	test "saves a request, queues its notification, and creates a Shopify draft order" do
		result = ShopifyServices::CreateDraftOrder::Result.new(draft_order_id: "gid://shopify/DraftOrder/123")

		with_draft_order_service(->(_intake) { result }) do
			assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
				post quote_requests_path, params: { quote_request: @payload }
			end
		end

		request = QuoteRequest.order(:created_at).last
		assert_response :redirect
		assert_redirected_to confirmation_quote_request_path(request.public_reference)
		assert_equal "submitted_review", request.status
		assert_equal "gid://shopify/DraftOrder/123", request.shopify_draft_order_id
	end

	test "keeps the quote when Shopify draft order creation fails" do
		with_draft_order_service(->(_intake) { raise ShopifyServices::CreateDraftOrder::Error, "Shopify unavailable" }) do
			assert_difference("QuoteRequest.count", 1) do
				post quote_requests_path, params: { quote_request: @payload }
			end
		end

		assert_response :redirect
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

	test "limits quote submissions to five per minute" do
		with_draft_order_service(->(_intake) { raise ShopifyServices::CreateDraftOrder::Error, "Shopify unavailable" }) do
			5.times { post quote_requests_path, params: { quote_request: @payload } }
			post quote_requests_path, params: { quote_request: @payload }
		end

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

	private

	def with_draft_order_service(replacement)
		service = ShopifyServices::CreateDraftOrder
		original = service.method(:call)
		service.define_singleton_method(:call) { |intake:| replacement.call(intake) }
		yield
	ensure
		service.define_singleton_method(:call, original)
	end
end
