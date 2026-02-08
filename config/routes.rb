Rails.application.routes.draw do
  # API routes
  namespace :api do
    namespace :v1 do
      resources :background_checks, only: [ :create, :show ]
    end
  end

  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check
end
