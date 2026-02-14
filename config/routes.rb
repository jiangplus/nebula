Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Authentication
  get "login", to: "sessions#new", as: :login_path
  post "login", to: "sessions#create"
  get "logout", to: "sessions#destroy", as: :logout_path

  get "signup", to: "registrations#new", as: :signup_path
  post "signup", to: "registrations#create"

  # Password reset
  get "reset", to: "password_resets#new", as: :new_password_reset
  post "reset", to: "password_resets#create"
  get "reset/:token", to: "password_resets#edit", as: :edit_password_reset
  patch "reset/:token", to: "password_resets#update"

  # OAuth
  post "auth/oauth/:provider", to: "oauth#authorize"
  get "auth/oauth/:provider/callback", to: "oauth#callback"

  # Email subscriptions
  post "api/collections/:collection_alias/email/subscribe", to: "email_subscriptions#create"
  delete "api/collections/:collection_alias/email/unsubscribe", to: "email_subscriptions#destroy"
  get "email/confirm/:token", to: "email_subscriptions#confirm"

  # API
  namespace :api do
    namespace :auth do
      post "signup", to: "registrations#create"
      post "login", to: "sessions#create"
      delete "logout", to: "sessions#destroy"
    end

    resource :me, only: [], controller: "users" do
      get "/", action: :show
    end

    resources :collections, param: :alias do
      resources :posts, only: [:index, :create, :show, :update], controller: "collections/posts"
      resource :inbox, only: [:create], controller: "activity_pub/inboxes"
      resource :outbox, only: [:show], controller: "activity_pub/outboxes"
      resource :followers, only: [:show], controller: "activity_pub/followers"
    end

    resources :posts, only: [:create, :show, :update, :destroy]
  end

  # User account
  scope "/me", as: :user do
    get "/", to: "users/accounts#show", as: :account
    get "settings", to: "users/accounts#show"
    patch "settings", to: "users/accounts#update"
    delete "/", to: "users/accounts#destroy"
    resources :collections, only: [:index, :show], path: "c", controller: "collections"
    resources :posts, only: [:index], controller: "posts"
  end

  # Draft posts
  get "new", to: "posts#new"
  get "d/:id", to: "posts#show", as: :draft_post
  get "d/:id/edit", to: "posts#edit"

  # Public collection pages
  get ":collection_alias", to: "collections/posts#index", as: :collection
  get ":collection_alias/:slug", to: "collections/posts#show", as: :collection_post

  # Admin
  scope "/admin", as: :admin do
    get "/", to: "admin#dashboard", as: :dashboard
    get "users", to: "admin#users_index", as: :users
    get "users/:id", to: "admin#show_user", as: :show_user
    delete "users/:id", to: "admin#delete_user", as: :delete_user
    patch "users/:id/status", to: "admin#toggle_user_status", as: :toggle_user_status
  end

  # Reader / Homepage (Chorus mode)
  root "home#index"
  get "read", to: "home#index", as: :reader
  get "read/page/:page", to: "home#index", as: :reader_page
end
