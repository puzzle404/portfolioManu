Rails.application.routes.draw do
  resources :projects
  resources :experiences do
    resources :photos, only: :destroy
  end


  devise_for :users
  root to: "pages#home"
end
