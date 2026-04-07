Rails.application.routes.draw do
  devise_for :users

  authenticate :user do
    root to: "dashboard#index", as: :authenticated_root
    get "dashboard", to: "dashboard#index", as: :dashboard

    resources :invoices do
      collection do
        post :upload_pdf
        post :bulk_create
      end
    end

    resources :reports, only: [] do
      collection do
        get :modelo303
      end
    end
  end

  # Redirect unauthenticated users to login
  root to: redirect("/users/sign_in")

  get "up" => "rails/health#show", as: :rails_health_check
end
