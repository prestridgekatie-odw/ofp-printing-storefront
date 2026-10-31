class QuoteRequestsController < ApplicationController
  before_action :block_direct_production_access
  before_action :authenticate_shopify_proxy_request!, if: :shopify_proxy_request?
  before_action :set_shopify_proxy_path_prefix, if: :shopify_proxy_request?
  skip_forgery_protection only: :create, if: :shopify_proxy_request?

  rate_limit to: 5, within: 1.minute, only: :create, store: Rails.cache,
    by: -> { request.remote_ip },
    with: -> { redirect_to(quote_entry_path, alert: "Too many attempts. Please wait a minute.") }

  def new
    @quote_request = QuoteRequest.new
    prepare_quote_form
  end

  def create
    @quote_request = QuoteRequest.new(quote_request_params)
    @quote_request.status = "submitted_review"

    unless valid_proxy_form_token?
      @quote_request.errors.add(:base, "This form expired. Please review your request and submit it again.")
      return render_quote_form
    end

    if params[:website].present?
      @quote_request.errors.add(:base, "We could not process that request.")
      return render_quote_form
    end

    if save_quote_request
      enqueue_notification
      enqueue_draft_order
      redirect_to confirmation_url
    else
      render_quote_form
    end
  end

  def confirmation
    @quote_request = QuoteRequest.find_by!(public_reference: params[:public_reference])
    @return_to_home_url = root_path
    @start_another_quote_url = shopify_proxy_request? ? @shopify_proxy_path_prefix : quote_path
  end

  private

  def block_direct_production_access
    head :not_found if Rails.env.production? && !shopify_proxy_request?
  end

  def shopify_proxy_request?
    request.path == "/shopify/proxy" || request.path.start_with?("/shopify/proxy/")
  end

  def authenticate_shopify_proxy_request!
    ShopifyServices::VerifyAppProxyRequest.call(request)
  rescue ShopifyServices::VerifyAppProxyRequest::InvalidRequest
    head :forbidden
  end

  def set_shopify_proxy_path_prefix
    @shopify_proxy_path_prefix = request.query_parameters.fetch("path_prefix")
  end

  def quote_entry_path
    shopify_proxy_request? ? @shopify_proxy_path_prefix : quote_path
  end

  def prepare_quote_form
    @quote_form_action = shopify_proxy_request? ? @shopify_proxy_path_prefix : quote_requests_path
    @return_to_home_url = root_path
    issue_proxy_form_token if shopify_proxy_request?
  end

  def issue_proxy_form_token
    @proxy_form_token = SecureRandom.urlsafe_base64(32)
    written = Rails.cache.write(proxy_form_token_cache_key(@proxy_form_token), true, expires_in: 30.minutes)
    raise ShopifyServices::VerifyAppProxyRequest::ConfigurationError, "Unable to issue a quote form token" unless written
  end

  def valid_proxy_form_token?
    return true unless shopify_proxy_request?

    token = params[:proxy_form_token].to_s
    token.match?(/\A[A-Za-z0-9_-]{43}\z/) && Rails.cache.delete(proxy_form_token_cache_key(token))
  end

  def proxy_form_token_cache_key(token)
    "shopify-proxy-quote-form:#{Digest::SHA256.hexdigest(token)}"
  end

  def render_quote_form
    prepare_quote_form
    render :new, status: :unprocessable_entity
  end

  def quote_request_params
    params.require(:quote_request).permit(
      :organization_name,
      :contact_name,
      :position_title,
      :phone,
      :email,
      :preferred_contact_method,
      :other_project_type,
      :quantity_summary,
      :needed_by,
      :event_date,
      :rush_request,
      :delivery_method,
      :description,
      :artwork_status,
      :information_confirmed,
      :contact_consent,
      project_types: [],
      project_details: permitted_project_detail_filters
    )
  end

  def permitted_project_detail_filters
    QuoteRequest::PROJECT_DETAIL_SECTIONS.to_h do |_, section|
      fields = section[:fields].map do |field, definition|
        definition[:type] == :multiple ? { field => [] } : field
      end
      [section[:key], fields]
    end
  end

  def enqueue_notification
    enqueue_integration_job(
      QuoteRequestNotificationJob,
      :notification_status,
      :notification_error,
      "notification"
    )
  end

  def enqueue_draft_order
    enqueue_integration_job(
      ShopifyDraftOrderJob,
      :shopify_draft_order_status,
      :shopify_draft_order_error,
      "draft order"
    )
  end

  def enqueue_integration_job(job_class, status_attribute, error_attribute, integration_name)
    begin
      job = job_class.perform_later(@quote_request.public_reference)
      raise ActiveJob::EnqueueError, "#{integration_name} job was not enqueued" unless job&.successfully_enqueued?
    rescue ActiveJob::EnqueueError, RedisClient::Error, Sidekiq::Error => error
      @quote_request.update!(status_attribute => "failed", error_attribute => error.class.name)
      Rails.logger.error("Quote request #{@quote_request.public_reference}: #{integration_name} job enqueue failed (#{error.class})")
      return
    end

    @quote_request.with_lock do
      @quote_request.update!(status_attribute => "queued", error_attribute => nil) if @quote_request.public_send(status_attribute) == "pending"
    end
  end

  def confirmation_url
    if shopify_proxy_request?
      "#{@shopify_proxy_path_prefix}/confirmation/#{@quote_request.public_reference}"
    else
      confirmation_quote_request_path(@quote_request.public_reference)
    end
  end

  def save_quote_request
    attempts = 0

    begin
      attempts += 1
      @quote_request.save
    rescue ActiveRecord::RecordNotUnique => error
      raise unless attempts < 3 && public_reference_collision?(error)

      @quote_request.public_reference = nil
      retry
    end
  end

  def public_reference_collision?(error)
    [error.message, error.cause&.message].compact.any? do |message|
      message.include?("public_reference")
    end
  end
end
