map.namespace :admin do |admin|
  admin.resources :reports, :collection => { :revenue => :get, :units => :get, :top_products => :get, :top_customers => :get, :geo_revenue => :get }
end
