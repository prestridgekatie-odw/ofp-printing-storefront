require "test_helper"

class QuoteRequestTest < ActiveSupport::TestCase
  test "validates and normalizes a quote request" do
    request = QuoteRequest.new(valid_attributes.merge(email: "  PERSON@EXAMPLE.COM ", phone: " 555 0100 "))

    assert request.valid?
    assert_equal "person@example.com", request.email
    assert_equal "555 0100", request.phone
    assert_match(/\AOFP-[A-Z0-9]{16}\z/, request.public_reference)
    assert_equal "new", request.status
  end

  test "stores project types as a JSON array with no more than five values" do
    request = QuoteRequest.new(valid_attributes.merge(project_types: QuoteRequest::PROJECT_TYPES.first(5)))

    assert request.valid?
    request.save!
    assert_equal QuoteRequest::PROJECT_TYPES.first(5), request.reload.project_types
  end

  test "requires a project type and rejects more than five" do
    assert_not QuoteRequest.new(valid_attributes.merge(project_types: [])).valid?
    assert_not QuoteRequest.new(valid_attributes.merge(project_types: QuoteRequest::PROJECT_TYPES.first(6))).valid?
  end

  test "removes blank and duplicate project types" do
    request = QuoteRequest.new(valid_attributes.merge(project_types: ["", "Sports Uniforms", "Sports Uniforms"]))

    assert request.valid?
    assert_equal ["Sports Uniforms"], request.project_types
  end

  test "rejects unknown project types" do
    request = QuoteRequest.new(valid_attributes.merge(project_types: ["Unknown service"]))

    assert_not request.valid?
    assert_includes request.errors[:project_types], "must contain one to five approved project types"
  end

  test "requires phone for phone or text contact" do
    assert_not QuoteRequest.new(valid_attributes.merge(phone: nil, preferred_contact_method: "phone")).valid?
    assert_not QuoteRequest.new(valid_attributes.merge(phone: nil, preferred_contact_method: "text")).valid?
    assert QuoteRequest.new(valid_attributes.merge(phone: nil, preferred_contact_method: "email")).valid?
  end

  test "requires other explanation only for Other" do
    assert_not QuoteRequest.new(valid_attributes.merge(project_types: ["Other"])).valid?
    assert QuoteRequest.new(valid_attributes.merge(project_types: ["Other"], other_project_type: "Custom display items")).valid?
    assert_not QuoteRequest.new(valid_attributes.merge(other_project_type: "Unselected explanation")).valid?
  end

  test "validates optional date ordering" do
    request = QuoteRequest.new(valid_attributes.merge(needed_by: Date.new(2026, 10, 2), event_date: Date.new(2026, 10, 1)))

    assert_not request.valid?
    assert_includes request.errors[:needed_by], "must be on or before the event date"
  end

  test "requires confirmation and consent" do
    request = QuoteRequest.new(valid_attributes.merge(information_confirmed: false, contact_consent: false))

    assert_not request.valid?
  end

  test "public references are unique" do
    first = QuoteRequest.create!(valid_attributes)
    second = QuoteRequest.new(valid_attributes.merge(public_reference: first.public_reference))

    assert_not second.valid?
    assert_includes second.errors[:public_reference], "has already been taken"
  end

  private

  def valid_attributes
    {
      contact_name: "Jordan Smith",
      email: "jordan@example.com",
      phone: "555-0100",
      preferred_contact_method: "email",
      project_types: ["Sports Uniforms"],
      quantity_summary: "24 uniforms",
      needed_by: Date.new(2026, 11, 1),
      description: "Uniforms for a community team.",
      artwork_status: "existing_artwork",
      delivery_method: "pickup",
      information_confirmed: true,
      contact_consent: true
    }
  end
end
