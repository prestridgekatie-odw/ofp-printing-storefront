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
  DETAIL_TEXT_LIMIT = 255
  DETAIL_SELECTION_LIMIT = 10
  PROJECT_DETAIL_SECTIONS = {
    "Sports Uniforms" => {
      key: "sports_uniforms",
      fields: {
        "sport" => { type: :single, required: true, values: %w[football basketball baseball_softball soccer volleyball wrestling cheer other not_sure] },
        "other_sport" => { type: :text, required_for: "sport" },
        "garment_types" => { type: :multiple, required: true, values: %w[jersey pants shorts warmup hoodie tshirt polo jacket hat other] },
        "other_garment_type" => { type: :text, required_for: "garment_types" },
        "decoration_methods" => { type: :multiple, required: true, values: %w[sublimation screen_print dtf embroidery tackle_twill vinyl puff_print not_sure other] },
        "other_decoration_method" => { type: :text, required_for: "decoration_methods" },
        "sizing_method" => { type: :single, values: %w[sizing_kit roster_later manual_sizes_later not_sure] },
        "design_includes" => { type: :multiple, values: %w[player_names numbers sponsor_logos american_flag league_logos custom_patterning metallic_gold camo gradients] }
      }
    },
    "Fan Apparel/Spirit Wear" => {
      key: "fan_apparel_spirit_wear",
      fields: {
        "garment_types" => { type: :multiple, required: true, values: %w[tshirt hoodie sweatshirt polo jacket shorts hat other] },
        "decoration_methods" => { type: :multiple, required: true, values: %w[screen_print dtf embroidery vinyl puff_print sublimation not_sure other] },
        "other_garment_type" => { type: :text, required_for: "garment_types" },
        "other_decoration_method" => { type: :text, required_for: "decoration_methods" },
        "brand_preference" => { type: :single, values: %w[nike adidas under_armour richardson yupoong new_era ogio no_preference other] },
        "other_brand_preference" => { type: :text, required_for: "brand_preference" }
      }
    },
    "Embroidery" => {
      key: "embroidery",
      fields: {
        "item_types" => { type: :multiple, values: %w[polo jacket hat bag uniform other] },
        "decoration_locations" => { type: :multiple, values: %w[left_chest right_chest front back sleeve hat_front hat_side other not_sure] },
        "other_item_type" => { type: :text, required_for: "item_types" },
        "other_decoration_location" => { type: :text, required_for: "decoration_locations" },
        "thread_color_notes" => { type: :text }
      }
    },
    "Screen Printing" => {
      key: "screen_printing",
      fields: {
        "garment_types" => { type: :multiple, values: %w[tshirt hoodie sweatshirt polo jacket other] },
        "print_locations" => { type: :multiple, values: %w[front back left_chest sleeve other] },
        "other_garment_type" => { type: :text, required_for: "garment_types" },
        "other_print_location" => { type: :text, required_for: "print_locations" },
        "estimated_color_count" => { type: :single, values: %w[one two three four_plus full_color not_sure] }
      }
    },
    "DTF Transfers" => {
      key: "dtf_transfers",
      fields: {
        "item_types" => { type: :multiple, values: %w[tshirt hoodie sweatshirt polo jacket bag other] },
        "application_locations" => { type: :multiple, values: %w[front back left_chest sleeve other] },
        "other_item_type" => { type: :text, required_for: "item_types" },
        "other_application_location" => { type: :text, required_for: "application_locations" },
        "transfer_size" => { type: :single, values: %w[small medium large oversized mixed not_sure] }
      }
    },
    "Sublimation" => {
      key: "sublimation",
      fields: {
        "product_types" => { type: :multiple, values: %w[uniform jersey shorts shirt banner other] },
        "other_product_type" => { type: :text, required_for: "product_types" },
        "design_coverage" => { type: :single, values: %w[front_only front_and_back full_coverage not_sure] }
      }
    },
    "Hats/Headwear" => {
      key: "hats_headwear",
      fields: {
        "hat_styles" => { type: :multiple, values: %w[fitted snapback trucker dad_hat beanie visor not_sure other] },
        "decoration_locations" => { type: :multiple, values: %w[front side back multiple not_sure] },
        "decoration_methods" => { type: :multiple, values: %w[embroidery patch dtf puff not_sure other] },
        "other_hat_style" => { type: :text, required_for: "hat_styles" },
        "other_decoration_method" => { type: :text, required_for: "decoration_methods" }
      }
    },
    "Large Format Vinyl" => {
      key: "large_format_vinyl",
      fields: {
        "application_type" => { type: :single, values: %w[window wall vehicle floor sign other] },
        "other_application_type" => { type: :text, required_for: "application_type" },
        "finished_dimensions" => { type: :text },
        "environment" => { type: :single, values: %w[indoor outdoor both not_sure] },
        "installation_needed" => { type: :single, values: %w[yes no not_sure] }
      }
    },
    "Banners/Signs" => {
      key: "banners_signs",
      fields: {
        "product_type" => { type: :single, values: %w[banner yard_sign rigid_sign window_sign wall_sign other] },
        "other_product_type" => { type: :text, required_for: "product_type" },
        "finished_dimensions" => { type: :text },
        "mounting_method" => { type: :single, values: %w[grommets pole_pockets adhesive stand not_sure other] },
        "other_mounting_method" => { type: :text, required_for: "mounting_method" },
        "environment" => { type: :single, values: %w[indoor outdoor both not_sure] }
      }
    },
    "Stickers/Labels" => {
      key: "stickers_labels",
      fields: {
        "shape" => { type: :single, values: %w[round square rectangle die_cut custom not_sure] },
        "dimensions" => { type: :text },
        "finish" => { type: :single, values: %w[matte gloss clear holographic not_sure] },
        "environment" => { type: :single, values: %w[indoor outdoor both not_sure] }
      }
    },
    "Promotional Products" => {
      key: "promotional_products",
      fields: {
        "product_category" => { type: :single, values: %w[drinkware bags office event_items giveaways other not_sure] },
        "other_product_category" => { type: :text, required_for: "product_category" },
        "product_notes" => { type: :text }
      }
    },
    "Other" => { key: "other", fields: {} }
  }.freeze
  PROJECT_DETAIL_KEYS = PROJECT_DETAIL_SECTIONS.transform_values { |section| section[:key] }.freeze

  before_validation :normalize_contact_details
  before_validation :normalize_project_details
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
  validate :project_details_are_valid

  private

  def normalize_contact_details
    self.email = email.to_s.strip.downcase
    self.phone = phone.to_s.strip.presence
    self.project_types = Array(project_types).reject(&:blank?).uniq
  end

  def normalize_project_details
    raw_details = project_details.respond_to?(:to_h) ? project_details.to_h : {}
    self.project_details = project_types.filter_map do |project_type|
      section = PROJECT_DETAIL_SECTIONS[project_type]
      next unless section

      raw_section = raw_details[section[:key]] || raw_details[section[:key].to_sym]
      next [section[:key], {}] unless raw_section.respond_to?(:to_h)
      raw_section = raw_section.to_h

      values = section[:fields].filter_map do |field, definition|
        raw_value = raw_section[field] || raw_section[field.to_sym]
        normalized_value = if definition[:type] == :multiple
                             Array(raw_value).select { |value| value.is_a?(String) }.map(&:strip).reject(&:blank?).uniq
                           elsif raw_value.is_a?(String)
                             raw_value.strip.presence
                           end
        [field, normalized_value] if normalized_value.present?
      end.to_h
      [section[:key], values]
    end.to_h
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

  def project_details_are_valid
    project_types.each do |project_type|
      section = PROJECT_DETAIL_SECTIONS[project_type]
      next unless section

      details = project_details.to_h[section[:key]] || {}
      section[:fields].each do |field, definition|
        value = details[field]
        if definition[:required] && value.blank?
          errors.add(:project_details, "#{project_type}: #{field.humanize} is required")
        end
        if definition[:type] == :text
          if value.present? && value.length > DETAIL_TEXT_LIMIT
            errors.add(:project_details, "#{project_type}: #{field.humanize} is too long")
          end
        elsif definition[:type] == :multiple
          unless value.blank? || value.is_a?(Array) && value.length <= DETAIL_SELECTION_LIMIT && value.all? { |item| definition[:values].include?(item) }
            errors.add(:project_details, "#{project_type}: #{field.humanize} contains an invalid selection")
          end
        elsif value.present? && !definition[:values].include?(value)
          errors.add(:project_details, "#{project_type}: #{field.humanize} contains an invalid selection")
        end
        selected_value = details[definition[:required_for]]
        selected_value = Array(selected_value) unless selected_value.is_a?(String)
        if definition[:required_for] && Array(selected_value).include?("other") && value.blank?
          errors.add(:project_details, "#{project_type}: #{field.humanize} is required when Other is selected")
        end
      end
    end
  end

  def project_details_for_notification
    project_types.filter_map do |project_type|
      section = PROJECT_DETAIL_SECTIONS[project_type]
      details = project_details.to_h[section[:key]].to_h
      fields = section[:fields].filter_map do |field, definition|
        value = details[field]
        next if value.blank?

        formatted_value = if definition[:type] == :multiple
                            value.map { |item| detail_option_label(item) }.join(", ")
                          else
                            detail_option_label(value)
                          end
        [field.humanize, formatted_value]
      end
      [project_type, fields] if fields.any?
    end.to_h
  end

  public :project_details_for_notification

  def detail_option_label(value)
    return "Not sure - recommend the best option" if value == "not_sure"

    value.to_s.humanize
  end

  public :detail_option_label
end