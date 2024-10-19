Rails.application.routes.draw do
  resources :projects
  resources :experiences do
    resources :photos, only: :destroy
  end

  resources :questions, only: [:index, :create]

  resources :contacts, only: [:index, :new, :create]
  devise_for :users
  root to: "pages#home"
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
end
