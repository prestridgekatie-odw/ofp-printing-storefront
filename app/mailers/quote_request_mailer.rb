class QuoteRequestMailer < ApplicationMailer
  def notification(quote_request)
    @quote_request = quote_request

    mail(
      to: "info@ofpprinting.com",
      from: ENV.fetch("OFP_MAIL_FROM"),
      reply_to: quote_request.email,
      subject: "New OFP quote request #{quote_request.public_reference}"
    )
  end
end