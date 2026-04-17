Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "projects#index"

  resources :projects, only: [ :show ]
  resources :conversations, only: [ :show, :update, :destroy ] do
    get :title, on: :member
    patch :restore, on: :member
    resources :labels, only: [ :create, :destroy ], controller: "conversation_labels"
  end
  get "/search", to: "searches#show", as: :search
  post "/sync", to: "sync#create", as: :sync
  get "/trash", to: "trash#index", as: :trash
  resources :labels, only: [ :index, :create, :update, :destroy ]
end
