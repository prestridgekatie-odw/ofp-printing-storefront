require "test_helper"

class DevelopmentConfigurationTest < ActiveSupport::TestCase
  DEVELOPMENT_CONFIG = Rails.root.join("config/environments/development.rb")

  test "keeps forgery protection enabled and scopes the origin override to Codespaces development" do
    config_source = DEVELOPMENT_CONFIG.read

    assert_match(/config\.assume_ssl = true if ENV\["CODESPACES"\] == "true"/, config_source)
    assert_match(/config\.action_controller\.forgery_protection_origin_check = false if ENV\["CODESPACES"\] == "true"/, config_source)
    refute_match(/skip_forgery_protection|allow_forgery_protection\s*=\s*false/, config_source)
    refute_match(/config\.action_controller\.allow_forgery_protection\s*=\s*false/, config_source)
    assert_equal false, Rails.application.config.action_controller.allow_forgery_protection
  end
end