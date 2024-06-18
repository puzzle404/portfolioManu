Rails.application.routes.draw do
  resources :projects
  devise_for :users
  root to: "pages#home"
end
