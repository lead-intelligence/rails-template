Rails.application.routes.draw do
  mount Railspress::Engine => "/railspress"
  draw :madmin
  get "docs", to: "docs#index", as: :docs
  get "docs/*slug", to: "docs#show", as: :doc, format: false
  get "blog", to: "blog#index", as: :blog
  get "blog/:id", to: "blog#show", as: :blog_post
  resources :chats, except: [ :edit, :update ] do
    resources :messages, only: [ :create ]
  end
  resources :support_chats, only: %i[ index show create ] do
    resource :photos, only: [ :create ], controller: "support_chat_photos"
  end
  resources :documents
  resources :notifications, only: [ :index ] do
    collection do
      patch :mark_all_read
    end
  end
  resources :models, only: [ :index, :show ] do
    collection do
      post :refresh
    end
  end
  resource :session
  resources :active_sessions, only: %i[index destroy] do
    collection do
      delete :revoke_others
    end
  end
  resource :registration, only: %i[new create destroy]
  resource :data_export, only: %i[create show]
  resource :profile, only: %i[edit update]
  resources :passwords, param: :token
  resources :email_confirmations, only: [ :new, :create, :show ], param: :token
  resources :email_changes, only: [ :show ], param: :token
  resource :feedback, only: %i[new create]
  get "feedback/photos/:signed_id", to: "feedback_photos#show", as: :feedback_photo

  namespace :admin do
    resources :feedbacks, only: [ :index ] do
      member do
        patch :resolve
      end
    end
  end

  mount SolidErrors::Engine => "/errors"
  mount Onlylogs::Engine, at: "/onlylogs"
  mount MissionControl::Jobs::Engine, at: "/jobs"
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "health" => "health#show", as: :health

  get "/sitemap.xml" => "sitemaps#show", as: :sitemap, defaults: { format: "xml" }
  get "/robots.txt" => "sitemaps#robots", as: :robots, defaults: { format: "text" }

  resource :javascript_errors, only: [ :create ]
  resource :error_feed, only: [ :show ]

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "pages#home"
end
