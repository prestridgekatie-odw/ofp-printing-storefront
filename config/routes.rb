Rails.application.routes.draw do
  root "hello#index"
  get "/quote", to: "quote_requests#new", as: :quote
  post "/quote_requests", to: "quote_requests#create", as: :quote_requests
  get "/quote_requests/:public_reference/confirmation", to: "quote_requests#confirmation", as: :confirmation_quote_request
end
