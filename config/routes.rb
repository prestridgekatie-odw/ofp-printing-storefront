Rails.application.routes.draw do
  root "hello#index"
  get "/up", to: "rails/health#show", as: :rails_health_check
  get "/quote", to: "quote_requests#new", as: :quote
  post "/quote_requests", to: "quote_requests#create", as: :quote_requests
  get "/quote_requests/:public_reference/confirmation", to: "quote_requests#confirmation", as: :confirmation_quote_request

  get "/shopify/proxy", to: "quote_requests#new", as: :shopify_quote
  post "/shopify/proxy", to: "quote_requests#create", as: :shopify_quote_requests
  get "/shopify/proxy/confirmation/:public_reference", to: "quote_requests#confirmation", as: :shopify_confirmation_quote_request
end
