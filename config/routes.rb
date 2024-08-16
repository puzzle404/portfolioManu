Rails.application.routes.draw do
  resources :projects
  resources :experiences do
    resources :photos, only: :destroy
  end

  resources :questions, only: [:index, :create]


  devise_for :users
  root to: "pages#home"
end
