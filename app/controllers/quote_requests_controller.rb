class QuoteRequestsController < ApplicationController
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  rate_limit to: 5, within: 1.hour, only: :create, store: RATE_LIMIT_STORE

  def new
    @quote_request = QuoteRequest.new
  end

  def create
    if honeypot_filled?
      @quote_request = QuoteRequest.new
      @quote_request.errors.add(:base, "We could not process that request.")
      return render :new, status: :unprocessable_entity
    end

    @quote_request = QuoteRequest.new(quote_request_params)

    if save_quote_request
      enqueue_notification
      redirect_to confirmation_quote_request_path(@quote_request.public_reference)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def confirmation
    @quote_request = QuoteRequest.find_by!(public_reference: params[:public_reference])
  end

  private

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

  def honeypot_filled?
    params[:website].present?
  end

  def enqueue_notification
    QuoteRequestMailer.notification(@quote_request).deliver_later
  rescue ActiveJob::EnqueueError => error
    Rails.logger.warn("Quote request notification could not be queued: #{error.class}")
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