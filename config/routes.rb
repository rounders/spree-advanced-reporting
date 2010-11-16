map.namespace :admin do |admin|
  admin.resources :reports, :collection => { :revenue => :get, :units => :get }
end
