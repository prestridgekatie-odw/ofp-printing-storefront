class QuoteRequestNotificationJob < ApplicationJob
  PROCESSING_LEASE = 15.minutes

  queue_as :default

  def perform(public_reference)
    quote_request = QuoteRequest.find_by!(public_reference: public_reference)
    return if quote_request.notification_status == "sent"

    quote_request.with_lock do
      return if quote_request.notification_status == "sent"
      return if quote_request.notification_status == "processing" && quote_request.updated_at > PROCESSING_LEASE.ago

      quote_request.update!(notification_status: "processing", notification_error: nil)
    end

    QuoteRequestMailer.notification(quote_request).deliver_now
    quote_request.update!(notification_status: "sent", notification_error: nil)
  rescue StandardError => error
    quote_request&.update!(notification_status: "failed", notification_error: error.class.name)
    Rails.logger.error("Quote request notification failed for #{public_reference} (#{error.class})")
    raise
  end
end
