Rails.application.routes.draw do
  resources :projects
  resources :experiences do
    resources :photos, only: :destroy
  end

  resources :questions, only: [:index, :create]

  resources :contacts, only: [:index, :new, :create]
  devise_for :users
  root to: "pages#home"

  # Finance assistant
  namespace :finance do
    resource :chat, only: [:show] do
      resources :messages, only: [:create]
    end
    resources :expenses, only: [:index, :update, :destroy]
  end
  get "/finance", to: "finance/chats#show", as: :finance_root
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
end
