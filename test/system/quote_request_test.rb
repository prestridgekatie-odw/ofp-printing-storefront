require "application_system_test_case"

class QuoteRequestSystemTest < ApplicationSystemTestCase
  test "visitor can view the quote form" do
    visit quote_path

    assert_selector "h1", text: "Tell us what you are creating."
    assert_selector "label", text: "Contact name"
    assert_selector "input[name='quote_request[contact_consent]']"
  end

  test "preserves selected project details and advances when active requirements are satisfied" do
    visit quote_path

    assert_selector "#project-details-sports-uniforms[hidden]"
    find("#project-type-sports-uniforms").click
    assert_selector "#project-details-sports-uniforms:not([hidden])"
    assert_equal "true", find("#project-type-sports-uniforms")["aria-expanded"]

    find("#project-type-fan-apparel-spirit-wear").click
    assert_selector "#project-details-fan-apparel-spirit-wear:not([hidden])"
    assert_selector "#project-details-embroidery[hidden]"

    find("#project-detail-sports_uniforms-sport-football").click
    find("#project-detail-sports_uniforms-garment_types-jersey").click
    find("#project-detail-sports_uniforms-decoration_methods-sublimation").click
    find("#project-detail-fan_apparel_spirit_wear-garment_types-hoodie").click
    find("#project-detail-fan_apparel_spirit_wear-decoration_methods-screen_print").click

    find("#project-type-sports-uniforms").click
    assert_selector "#project-details-sports-uniforms[hidden]"
    assert find("#project-detail-sports_uniforms-sport-football", visible: false).disabled?
    assert find("#project-detail-sports_uniforms-sport-football", visible: false).checked?
    assert_selector "#project-details-fan-apparel-spirit-wear:not([hidden])"

    find("#project-type-sports-uniforms").click
    assert find("#project-detail-sports_uniforms-sport-football").checked?
    assert find("#project-detail-sports_uniforms-garment_types-jersey").checked?
    assert find("#project-detail-fan_apparel_spirit_wear-garment_types-hoodie").checked?
    assert_selector "#project-details-sports-uniforms:not([hidden])"

    fill_in "Estimated quantity or quantity summary", with: "24 items"
    choose "Have existing artwork"
    within "[data-step='2']" do
      click_button "Continue"
    end
    assert_selector "[data-step='3']:not([hidden])"
  end
end
