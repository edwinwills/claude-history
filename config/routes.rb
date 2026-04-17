Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "projects#index"

  resources :projects, only: [ :show ]
  resources :conversations, only: [ :show, :update ] do
    get :title, on: :member
  end
  get "/search", to: "searches#show", as: :search
  post "/sync", to: "sync#create", as: :sync
end
