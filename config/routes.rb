Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "projects#index"

  resources :projects, only: [ :show ]
  resources :conversations, only: [ :show ]
  get "/search", to: "searches#show", as: :search
  post "/sync", to: "sync#create", as: :sync
end
