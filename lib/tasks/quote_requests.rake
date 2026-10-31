namespace :quotes do
  desc "Re-enqueue failed quote notification and Draft Order integrations"
  task :retry_integrations, [:public_reference] => :environment do |_task, args|
    reference = args[:public_reference].to_s
    abort "Usage: bin/rails quotes:retry_integrations[OFP-REFERENCE]" if reference.blank?

    quote_request = QuoteRequest.find_by!(public_reference: reference)
    retried = false
    enqueue_retry = lambda do |job_class, status_attribute, error_attribute, label|
      begin
        job = job_class.perform_later(reference)
        raise ActiveJob::EnqueueError, "#{label} retry was not enqueued" unless job&.successfully_enqueued?
      rescue ActiveJob::EnqueueError, RedisClient::Error, Sidekiq::Error => error
        quote_request.update!(status_attribute => "failed", error_attribute => error.class.name)
        raise
      end

      quote_request.with_lock do
        if %w[pending failed].include?(quote_request.public_send(status_attribute))
          quote_request.update!(status_attribute => "queued", error_attribute => nil)
        end
      end
      retried = true
      puts "#{label} retry enqueued for #{reference}"
    end

    if %w[pending failed].include?(quote_request.notification_status)
      enqueue_retry.call(QuoteRequestNotificationJob, :notification_status, :notification_error, "Notification")
    end
    if %w[pending failed].include?(quote_request.shopify_draft_order_status)
      enqueue_retry.call(ShopifyDraftOrderJob, :shopify_draft_order_status, :shopify_draft_order_error, "Draft Order")
    end
    abort "No pending or failed quote integrations to retry for #{reference}" unless retried
  end
end
