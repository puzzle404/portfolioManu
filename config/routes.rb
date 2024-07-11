Rails.application.routes.draw do
  resources :projects
  resources :experiences
  devise_for :users
  root to: "pages#home"
end
