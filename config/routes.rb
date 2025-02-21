Rails.application.routes.draw do
  get '/api/0.1/swagger_doc.json/:all(*format)' => redirect('/api/0.1/swagger_doc/%{all}%{format}') # Workaround for silly swagger-codegen
  get '/api/100/swagger_doc.json/:all(*format)' => redirect('/api/100/swagger_doc/%{all}%{format}') # Workaround for silly swagger-codegen
  mount ApiRoot => '/api'
  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?

  authenticated :user, -> user { user.admin? }  do
    match '/delayed_job' => DelayedJobWeb, :anchor => false, :via => [:get, :post]
    mount DelayedJobWeb, at: "/delayed_job"
    mount RailsPerformance::Engine, at: 'rails/performance'
  end

  devise_for :users, :controllers => {:registrations => "registrations"}
  devise_for :vehicles
  devise_scope :user do
    unauthenticated do
      root 'index#index', as: :apikey_root, constraints: {url: /\?api_key=/}
      root 'devise/sessions#new', as: :unauthenticated_root
    end
  end

  get 'user_settings/:id' => 'users#show', :as => 'show_user'
  get 'edit_user_settings/:id' => 'users#edit_settings', :as => 'edit_user_settings'
  patch 'user_settings/:id' => 'users#update_settings', :as => 'update_user_settings'

  resources :users, only: [:edit, :update] do
    member do
      get :password
      patch :set_password
    end
  end

  namespace :admin do
    resources :users do
      member do
        get :send_email
      end
    end
    delete 'users' => 'users#destroy_multiple'
    resources :profiles
    resources :resellers
  end

  namespace :api_web, path: 'api-web' do
    namespace :v01, path: '0.1' do
      match 'destinations' => 'destinations#index', :as => 'destinations', via: [:get, :post]
      get 'destinations/:id/edit_position' => 'destinations#edit_position', :as => 'edit_position_destination'
      patch 'destinations/:id/update_position' => 'destinations#update_position', :as => 'update_position_destination'

      match 'stores' => 'stores#index', :as => 'stores', via: [:get, :post]
      get 'stores/:id/edit_position' => 'stores#edit_position', :as => 'edit_position_store'
      patch 'stores/:id/update_position' => 'stores#update_position', :as => 'update_position_store'
      get 'stores/:id' => 'stores#show'
      get 'stores/by_distance' => 'stores#by_distance', :as => 'stores_by_distance'

      get 'zonings/:id/edit' => 'zonings#edit', :as => 'edit_zoning'
      patch 'zonings/:id/edit' => 'zonings#update'
      match 'zonings/:zoning_id/zones' => 'zones#index', :as => 'zones', via: [:get, :post]

      get 'plannings/:id/edit' => 'plannings#edit', :as => 'edit_planning'
      get 'plannings/:planning_id/routes' => 'routes#index', :as => 'routes'
      get 'plannings/:id/print' => 'plannings#print', :as => 'print_planning'
      get 'plannings/:planning_id/routes/:id/print' => 'routes#print', :as => 'print_route'

      get 'stops/:id' => 'stops#show'
      get 'routes/:route_id/stops/by_index/:index' => 'stops#show'

      get 'visits/:id' => 'visits#show'

      get 'destinations/:id' => 'destinations#show'
    end
  end

  # get 'zonings/:zoning_id/edit' => 'zonings_api_web#edit', :as => 'edit_zoning'
      # patch 'zonings/:zoning_id/edit' => 'zonings_api_web#update'

  resources :tags
  delete 'tags' => 'tags#destroy_multiple'

  resources :customers do
    collection do
      get :import
      post :upload_dump
      delete :destroy_multiple
    end
    member do
      delete :delete_vehicle
      delete :delete_multiple_vehicles
      patch :duplicate
      get :export
    end
  end

  resources :vehicle_usage_sets do
    collection do
      get :import, to: 'vehicle_usage_sets#import'
      get :import_template, to: 'vehicle_usage_sets#import_template'
      post :upload_csv, to: 'vehicle_usage_sets#upload_csv', :as => 'import_csv'
    end
    patch 'duplicate'
  end
  delete 'vehicle_usage_sets' => 'vehicle_usage_sets#destroy_multiple'

  resources :vehicle_usages do
    member do
      patch :toggle
    end
  end

  resources :destinations
  get 'destination/import_template' => 'destinations#import_template'
  get 'destination/import' => 'destinations#import'
  post 'destinations/upload_csv' => 'destinations#upload_csv', :as => 'destinations_import_csv'
  post 'destinations/upload_tomtom' => 'destinations#upload_tomtom', :as => 'destinations_import_tomtom'
  delete 'destinations' => 'destinations#clear'

  resources :stores
  get 'store/import_template' => 'stores#import_template'
  get 'store/import' => 'stores#import'
  post 'stores/upload_csv' => 'stores#upload_csv', :as => 'stores_import_csv'
  delete 'stores' => 'stores#destroy_multiple'

  resources :plannings do
    patch ':route_id/:stop_id/move' => 'plannings#move'
    patch ':route_id/:stop_id/driver_move' => 'plannings#driver_move'
    patch ':route_id/:stop_id/move/:index' => 'plannings#move'
    patch ':route_id/move/' => 'plannings#move'
    get 'data_header'
    patch 'filter_routes'
    get 'refresh'
    get 'sidebar'
    get 'modal'
    patch 'switch'
    patch 'duplicate'
    patch ':route_id/active/:active' => 'plannings#active'
    patch ':route_id/reverse_order' => 'plannings#reverse_order'
    patch ':route_id/:stop_id' => 'plannings#update_stop'
    get 'optimize' => 'plannings#optimize'
    get ':route_id/refresh' => 'plannings#refresh_route'
    get ':route_id/optimize' => 'plannings#optimize_route'
    delete 'optimize' => 'plannings#cancel_optimize'
    member do
      patch :apply_zonings
      patch :automatic_insert
    end
    patch 'update_stops_status'
  end
  delete 'plannings' => 'plannings#destroy_multiple'

  resources :custom_attributes do
    patch 'update_default_value_partial' => 'custom_attributes#update_default_value_partial'
  end
  post 'reset_default_value_partial' => 'custom_attributes#reset_default_value_partial'
  delete 'custom_attributes' => 'custom_attributes#destroy_multiple'

  resources :deliverable_units
  delete 'deliverable_units' => 'deliverable_units#destroy_multiple'

  resources :products
  delete 'products' => 'products#destroy_multiple'

  resources :routes do
    get 'modal'
  end
  get 'routes/:id/mobile' => 'routes#mobile'
  patch 'routes/:id/update_position' => 'routes#update_position'

  resources :stops
  get 'routes/:route_id/stops/by_index/:index' => 'stops#show'

  get 'routes_by_vehicles/:vehicle_id' => 'routes_by_vehicles#show'
  get 'plannings_by_destinations/:destination_id' => 'plannings_by_destinations#show'
  get 'deliverables_by_vehicles/:vehicle_id' => 'deliverables_by_vehicles#show'

  get 'visits/:id' => 'visits#show'

  get '/zonings/new/planning/:planning_id' => 'zonings#new', as: :new_zonings_planning
  resources :zonings do
    get 'edit/planning/:planning_id' => 'zonings#edit'
    get 'planning/:planning_id' => 'zonings#show'
    patch 'duplicate'
    patch 'automatic' => 'zonings#automatic'
    patch 'automatic/planning/:planning_id' => 'zonings#automatic'
    patch 'from_planning/planning/:planning_id' => 'zonings#from_planning'
    patch 'isochrone' => 'zonings#isochrone'
    patch 'isodistance' => 'zonings#isodistance'
  end
  delete 'zonings' => 'zonings#destroy_multiple'

  resources :zones

  resources :order_arrays do
    patch 'duplicate'
  end
  delete 'order_arrays' => 'order_arrays#destroy_multiple'

  get '/unsupported_browser' => 'index#unsupported_browser'

  get '/images/marker-home' => 'images#marker_home'
  get '/images/marker-home-:color' => 'images#marker_home'
  get '/images/marker' => 'images#marker'
  get '/images/marker-:color' => 'images#marker'
  get '/images/point' => 'images#point'
  get '/images/point-:color' => 'images#point'
  get '/images/square' => 'images#square'
  get '/images/square-:color' => 'images#square'
  get '/images/diamon' => 'images#diamon'
  get '/images/diamon-:color' => 'images#diamon'
  get '/images/star' => 'images#star'
  get '/images/star-:color' => 'images#star'
  get '/images/user' => 'images#user'
  get '/images/user-:color' => 'images#user'
  get '/images/point_large' => 'images#point_large'
  get '/images/point_large-:color' => 'images#point_large'

  resources :reporting
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'index#index'

  # Errors
  %w(404 406 422 500).each do |code|
    get code, to: 'errors#show', code: code
  end
end
