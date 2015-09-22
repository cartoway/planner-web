Rails.application.routes.draw do
  namespace :api_web, path: 'api-web' do
    namespace :v01, path: '0.1' do
      get 'stores/by_distance' => 'stores#by_distance', :as => 'stores_by_distance'
    end
  end
end
