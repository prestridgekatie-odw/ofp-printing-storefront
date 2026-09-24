require "application_system_test_case"

class QuoteRequestSystemTest < ApplicationSystemTestCase
  test "visitor can view the quote form" do
    visit quote_path

    assert_selector "h1", text: "Tell us what you are creating."
    assert_selector "label", text: "Contact name"
    assert_selector "input[name='quote_request[contact_consent]']"
  end

  test "reveals and resets conditional project details" do
    visit quote_path

    find("#project-type-sports-uniforms").click
    assert_selector "#project-details-sports-uniforms:not([hidden])"
    assert_equal "true", find("#project-type-sports-uniforms")["aria-expanded"]

    find("#project-detail-sports_uniforms-sport-football").click
    find("#project-type-sports-uniforms").click
    assert_selector "#project-details-sports-uniforms[hidden]"
    assert find("#project-detail-sports_uniforms-sport-football", visible: false).disabled?

    find("#project-type-sports-uniforms").click
    assert_not find("#project-detail-sports_uniforms-sport-football").selected?
    assert_selector "#project-details-sports-uniforms:not([hidden])"
  end
end
