require "application_system_test_case"

class QuoteRequestSystemTest < ApplicationSystemTestCase
  test "visitor can view the quote form" do
    visit quote_path

    assert_selector "h1", text: "Tell us what you are creating."
    assert_selector "label", text: "Contact name"
    assert_selector "input[name='quote_request[contact_consent]']"
  end
end
