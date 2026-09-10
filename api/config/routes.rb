Rails.application.routes.draw do
  defaults format: :json do
    get "/health", to: "health#show"
    resources :lookups, only: [ :create, :index ]
    resources :process_events, only: [ :create, :index ]
    match "*path", to: "application#not_found", via: :all
    match "/", to: "application#not_found", via: :all
  end
end
