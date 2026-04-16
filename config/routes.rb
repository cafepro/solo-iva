Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  devise_for :users

  authenticate :user do
    root to: "dashboard#index", as: :authenticated_root
    get "dashboard", to: "dashboard#index", as: :dashboard

    resources :invoices do
      collection do
        post :upload_pdf
        post :bulk_create
        get  :review
        post :upload_pdfs
      end
      member do
        get :pdf
        patch :confirm
      end
    end

    resources :clients, except: :show

    resources :service_templates

    resource :billing_profile, only: %i[show update]

    resource :ai_integrations, only: %i[show update], controller: "ai_integrations" do
      post :check, on: :collection
    end

    resources :pdf_uploads, only: :destroy

    resources :reports, only: [] do
      collection do
        get :modelo303
      end
    end

    resource :google_drive_settings, only: %i[show update], controller: "google_drive_settings" do
      get :authorize, on: :collection
      get :callback, on: :collection
      delete :disconnect, on: :collection
    end
  end

  # Redirect unauthenticated users to login
  root to: redirect("/users/sign_in")

  get "up" => "rails/health#show", as: :rails_health_check
end
