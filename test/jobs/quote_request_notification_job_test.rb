require "test_helper"

class QuoteRequestNotificationJobTest < ActiveJob::TestCase
  setup do
    @previous_mail_from = ENV["OFP_MAIL_FROM"]
    ENV["OFP_MAIL_FROM"] = "notifications@example.test"
    @quote_request = QuoteRequest.create!(
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
      information_confirmed: true,
      contact_consent: true,
      notification_status: "queued"
    )
  end

  teardown do
    ENV["OFP_MAIL_FROM"] = @previous_mail_from
  end

  test "delivers the internal notification and records success" do
    delivered_before = ActionMailer::Base.deliveries.size
    QuoteRequestNotificationJob.perform_now(@quote_request.public_reference)
    QuoteRequestNotificationJob.perform_now(@quote_request.public_reference)

    assert_equal delivered_before + 1, ActionMailer::Base.deliveries.size
    assert_equal "sent", @quote_request.reload.notification_status
  end

  test "records and re-raises a failed email delivery" do
    delivery = Object.new
    delivery.define_singleton_method(:deliver_now) { raise IOError, "SMTP unavailable" }
    mailer = QuoteRequestMailer
    original_notification = mailer.method(:notification)
    mailer.define_singleton_method(:notification) { |_quote_request| delivery }

    assert_raises(IOError) do
      QuoteRequestNotificationJob.perform_now(@quote_request.public_reference)
    end

    assert_equal "failed", @quote_request.reload.notification_status
    assert_equal "IOError", @quote_request.notification_error
  ensure
    mailer.define_singleton_method(:notification, original_notification)
  end
end
