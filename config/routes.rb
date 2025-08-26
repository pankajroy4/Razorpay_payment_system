# config/routes.rb
Rails.application.routes.draw do
  root "payments#new"
  resources :payments, only: [:index, :new, :create, :show]
  resources :payments, only: [:index, :new, :create, :show] do 
    post :abandon, on: :member
    resources :refunds, only: [:create]
  end

  # Razorpay webhook endpoint (publicly reachable URL; use ngrok in dev)
  post "/razorpay/webhook", to: "payments#webhook"
end
