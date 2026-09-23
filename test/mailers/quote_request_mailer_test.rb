require "test_helper"

class QuoteRequestMailerTest < ActionMailer::TestCase
  setup do
    @previous_mail_from = ENV["OFP_MAIL_FROM"]
    ENV["OFP_MAIL_FROM"] = "notifications@example.test"
    @quote_request = QuoteRequest.new(
      contact_name: "Jordan Smith",
      email: "jordan@example.com",
      phone: "555-0100",
      preferred_contact_method: "email",
      project_types: ["Sports Uniforms"],
      quantity_summary: "24 uniforms",
      description: "Uniforms for a community team.",
      artwork_status: "existing_artwork",
      delivery_method: "pickup",
      information_confirmed: true,
      contact_consent: true
    )
    @quote_request.valid?
  end

  teardown do
    ENV["OFP_MAIL_FROM"] = @previous_mail_from
  end

  test "sends to OFP with configured From and requester Reply-To" do
    mail = QuoteRequestMailer.notification(@quote_request)

    assert_equal ["info@ofpprinting.com"], mail.to
    assert_equal ["notifications@example.test"], mail.from
    assert_equal ["jordan@example.com"], mail.reply_to
    assert_includes mail.subject, @quote_request.public_reference
  end
end
