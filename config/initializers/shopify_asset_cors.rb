Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("SHOPIFY_STOREFRONT_ORIGINS", "https://www.ofpprinting.com").split(",").map(&:strip))
    resource "/assets/*", headers: :any, methods: %i[get head]
  end
end
