class QuoteRequest < ApplicationRecord
  PROJECT_TYPES = [
    "Sports Uniforms",
    "Fan Apparel/Spirit Wear",
    "Embroidery",
    "Screen Printing",
    "DTF Transfers",
    "Sublimation",
    "Hats/Headwear",
    "Large Format Vinyl",
    "Banners/Signs",
    "Stickers/Labels",
    "Promotional Products",
    "Other"
  ].freeze
  CONTACT_METHODS = %w[phone email text].freeze
  DELIVERY_METHODS = %w[pickup shipping local_delivery].freeze
  ARTWORK_STATUSES = %w[full_design existing_artwork minor_edits reorder].freeze
  STATUSES = ["new"].freeze

  before_validation :normalize_contact_details
  before_validation :generate_public_reference, on: :create

  validates :contact_name, :email, :preferred_contact_method, :quantity_summary,
    :description, :delivery_method, :artwork_status, presence: true
  validates :organization_name, :position_title, :phone, :other_project_type,
    length: { maximum: 255 }, allow_blank: true
  validates :email, length: { maximum: 255 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true, if: -> { %w[phone text].include?(preferred_contact_method) }
  validates :preferred_contact_method, inclusion: { in: CONTACT_METHODS }
  validates :delivery_method, inclusion: { in: DELIVERY_METHODS }
  validates :artwork_status, inclusion: { in: ARTWORK_STATUSES }
  validates :status, inclusion: { in: STATUSES }
  validates :other_project_type, presence: true, if: -> { project_types.include?("Other") }
  validates :quantity_summary, length: { maximum: 255 }
  validates :description, length: { maximum: 5000 }
  validates :information_confirmed, acceptance: true
  validates :contact_consent, acceptance: true
  validates :public_reference, presence: true, uniqueness: true
  validate :project_types_are_valid
  validate :dates_are_in_order
  validate :other_project_type_is_only_for_other

  private

  def normalize_contact_details
    self.email = email.to_s.strip.downcase
    self.phone = phone.to_s.strip.presence
    self.project_types = Array(project_types).reject(&:blank?).uniq
  end

  def generate_public_reference
    self.public_reference ||= loop do
      reference = "OFP-#{SecureRandom.alphanumeric(16).upcase}"
      break reference unless self.class.exists?(public_reference: reference)
    end
  end

  def dates_are_in_order
    return if needed_by.blank? || event_date.blank? || needed_by <= event_date

    errors.add(:needed_by, "must be on or before the event date")
  end

  def project_types_are_valid
    return if project_types.is_a?(Array) && project_types.length.between?(1, 5) && project_types.all? { |type| PROJECT_TYPES.include?(type) }

    errors.add(:project_types, "must contain one to five approved project types")
  end

  def other_project_type_is_only_for_other
    return if project_types.include?("Other") || other_project_type.blank?

    errors.add(:other_project_type, "is only needed when Other is selected")
  end
end